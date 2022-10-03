from typing import List
import math
import numpy as np
from lib.amm.amm_base import *

# Type aliases
uint256 = float
uint256_N_COINS = List[float]
address = str

# Constants
PRECISION = 1 # 10 ** 18  # The precision to convert to
PRECISIONS = [1, #10 ** (18 - ERC20(_coins[0]).decimals()),
              1] #10 ** (18 - ERC20(_coins[1]).decimals())]
N_COINS = 2
A_MULTIPLIER = 10000

MAX_ADMIN_FEE = 10 * 10 ** 9 / 10**10
MIN_FEE = 5 * 10 ** 5 / 10**10  # 0.5 bps
MAX_FEE = 10 * 10 ** 9 / 10**10
MAX_A_CHANGE = 10
NOISE_FEE = 10**5 / 10**10  # 0.1 bps

MIN_GAMMA = 10**10 / 10**18
MAX_GAMMA = 2 * 10**16 / 10**18

MIN_A = N_COINS**N_COINS * A_MULTIPLIER / 10 / 10**18
MAX_A = N_COINS**N_COINS * A_MULTIPLIER * 100000 / 10**18

NEWTON_MAX_ITERATIONS = 1000

TMP_ACCOUNT = "tmp_account"

def unsafe_add(a, b):
    return a + b

def unsafe_sub(a, b):
    #assert a >= b
    return a - b

def unsafe_mul(a, b):
    return a * b

def unsafe_div(a, b):
    #assert b > 0
    return a / b

class CurveV2Pool(AmmBase):

    def __init__(
            self,
            pool_account,
            token_A, token_B,
            rewards_account, rewards_period,
            A,
            gamma,
            mid_fee,
            out_fee,
            allowed_extra_profit,
            fee_gamma,
            adjustment_step,
            admin_fee,
            ma_half_time,
            initial_price
    ):
        # fee doesn’t matter, as we are overriding swap functions
        super().__init__(pool_account, token_A, token_B, mid_fee / 10 ** 10, rewards_account, rewards_period)
        self.coins = [token_A, token_B]
        self.is_killed = False
        self.not_adjusted = False
        self.balances = [0, 0]

        self.initial_A_gamma = [A, gamma]
        self.future_A_gamma = [A, gamma]
        self.future_A_gamma_time = 0

        self.D = 0

        self.mid_fee = mid_fee
        self.out_fee = out_fee
        self.allowed_extra_profit = allowed_extra_profit
        self.fee_gamma = fee_gamma
        self.adjustment_step = adjustment_step
        self.admin_fee = admin_fee
        self.admin_fee_receiver = "Curve Admin"

        self.price_scale = initial_price
        self._price_oracle = initial_price
        self.last_prices = initial_price
        self.last_prices_timestamp = 0
        self.ma_half_time = ma_half_time

        self.xcp_profit_a = PRECISION

        self.token_A.mint(TMP_ACCOUNT, 1e32)

        return

    ### Math functions
    def geometric_mean(self, unsorted_x: uint256_N_COINS, sort: bool) -> uint256:
        """
        (x[0] * x[1] * ...) ** (1/N)
        """
        return (unsorted_x[0] * unsorted_x[1]) ** (1/2)

    def newton_D_bigint(self, ANN: uint256, gamma: uint256, x_unsorted: uint256_N_COINS) -> uint256:
        # Convert to bigints
        ANN *= 10**18
        gamma *= 10**18
        x_unsorted[0] *= 10**18
        x_unsorted[1] *= 10**18
        """
        Finding the invariant using Newton method.
        ANN is higher by the factor A_MULTIPLIER
        ANN is already A * N**N

        Currently uses 60k gas
        """
        # Safety checks
        assert ANN > MIN_A * 10**18 - 1 and ANN < MAX_A * 10**18 + 1  # dev: unsafe values A
        assert gamma > MIN_GAMMA * 10**18 - 1 and gamma < MAX_GAMMA * 10**18 + 1  # dev: unsafe values gamma

        # Initial value of invariant D is that for constant-product invariant
        x: uint256[N_COINS] = x_unsorted
        if x[0] < x[1]:
            x = [x_unsorted[1], x_unsorted[0]]

        assert x[0] > 10**9 - 1 and x[0] < 10**15 * 10**18 + 1  # dev: unsafe values x[0]
        assert x[1] * 10**18 / x[0] > 10**14-1  # dev: unsafe values x[i] (input)

        D: uint256 = N_COINS * self.geometric_mean(x, False)
        S: uint256 = x[0] + x[1]
        __g1k0: uint256 = gamma + 10**18

        for i in range(255):
            D_prev: uint256 = D
            assert D > 0
            # Unsafe ivision by D is now safe

            # K0: uint256 = 10**18
            # for _x in x:
            #     K0 = K0 * _x * N_COINS / D
            # collapsed for 2 coins
            K0: uint256 = unsafe_div(unsafe_div((10**18 * N_COINS**2) * x[0], D) * x[1], D)

            _g1k0: uint256 = __g1k0
            if _g1k0 > K0:
                _g1k0 = unsafe_sub(_g1k0, K0) + 1  # > 0
            else:
                _g1k0 = unsafe_sub(K0, _g1k0) + 1  # > 0

            # D / (A * N**N) * _g1k0**2 / gamma**2
            mul1: uint256 = unsafe_div(unsafe_div(unsafe_div(10**18 * D, gamma) * _g1k0, gamma) * _g1k0 * A_MULTIPLIER, ANN)

            # 2*N*K0 / _g1k0
            mul2: uint256 = unsafe_div(((2 * 10**18) * N_COINS) * K0, _g1k0)

            neg_fprime: uint256 = (S + unsafe_div(S * mul2, 10**18)) + mul1 * N_COINS / K0 - unsafe_div(mul2 * D, 10**18)

            # D -= f / fprime
            D_plus: uint256 = D * (neg_fprime + S) / neg_fprime
            D_minus: uint256 = D*D / neg_fprime
            if 10**18 > K0:
                D_minus += unsafe_div(D * (mul1 / neg_fprime), 10**18) * unsafe_sub(10**18, K0) / K0
            else:
                D_minus -= unsafe_div(D * (mul1 / neg_fprime), 10**18) * unsafe_sub(K0, 10**18) / K0

            if D_plus > D_minus:
                D = unsafe_sub(D_plus, D_minus)
            else:
                D = unsafe_div(unsafe_sub(D_minus, D_plus), 2)

            diff: uint256 = 0
            if D > D_prev:
                diff = unsafe_sub(D, D_prev)
            else:
                diff = unsafe_sub(D_prev, D)
            if diff * 10**14 < max(10**16, D):  # Could reduce precision for gas efficiency here
                # Test that we are safe with the next newton_y
                for _x in x:
                    frac: uint256 = _x * 10**18 / D
                    assert (frac > 10**16 - 1) and (frac < 10**20 + 1)  # dev: unsafe values x[i]
                return D / 10**18

        raise "Did not converge"

    def newton_D(self, ANN: uint256, gamma: uint256, x_unsorted: uint256_N_COINS) -> uint256:
        """
        Finding the invariant using Newton method.
        ANN is higher by the factor A_MULTIPLIER
        ANN is already A * N**N

        Currently uses 60k gas
        """
        # Safety checks
        assert ANN >= MIN_A and ANN <= MAX_A  # dev: unsafe values A
        assert gamma >= MIN_GAMMA and gamma <= MAX_GAMMA  # dev: unsafe values gamma

        # Initial value of invariant D is that for constant-product invariant
        x: uint256_N_COINS = x_unsorted
        if x[0] < x[1]:
            x = [x_unsorted[1], x_unsorted[0]]

        assert x[0] > 10**(-9) and x[0] < 10**15 * PRECISION + 1  # dev: unsafe values x[0]
        assert x[1] * PRECISION / x[0] > 10**(-4)-1  # dev: unsafe values x[i] (input)

        D: uint256 = N_COINS * self.geometric_mean(x, False)
        S: uint256 = x[0] + x[1]
        __g1k0: uint256 = gamma + PRECISION

        for i in range(255):
            D_prev: uint256 = D
            assert D > 0
            # Unsafe ivision by D is now safe

            # K0: uint256 = 10**18
            # for _x in x:
            #     K0 = K0 * _x * N_COINS / D
            # collapsed for 2 coins
            K0: uint256 = unsafe_div(unsafe_div((PRECISION * N_COINS**2) * x[0], D) * x[1], D)

            _g1k0: uint256 = __g1k0
            if _g1k0 > K0:
                _g1k0 = unsafe_sub(_g1k0, K0) + 1  # > 0
            else:
                _g1k0 = unsafe_sub(K0, _g1k0) + 1  # > 0

            # D / (A * N**N) * _g1k0**2 / gamma**2
            mul1: uint256 = unsafe_div(unsafe_div(unsafe_div(PRECISION * D, gamma) * _g1k0, gamma) * _g1k0 * A_MULTIPLIER, ANN)

            # 2*N*K0 / _g1k0
            mul2: uint256 = unsafe_div(((2 * PRECISION) * N_COINS) * K0, _g1k0)

            neg_fprime: uint256 = (S + unsafe_div(S * mul2, PRECISION)) + mul1 * N_COINS / K0 - unsafe_div(mul2 * D, PRECISION)

            # D -= f / fprime
            D_plus: uint256 = D * (neg_fprime + S) / neg_fprime
            D_minus: uint256 = D*D / neg_fprime
            if PRECISION > K0:
                D_minus += unsafe_div(D * (mul1 / neg_fprime), PRECISION) * unsafe_sub(PRECISION, K0) / K0
            else:
                D_minus -= unsafe_div(D * (mul1 / neg_fprime), PRECISION) * unsafe_sub(K0, PRECISION) / K0

            if D_plus > D_minus:
                D = unsafe_sub(D_plus, D_minus)
            else:
                D = unsafe_div(unsafe_sub(D_minus, D_plus), 2)

            diff: uint256 = 0
            if D > D_prev:
                diff = unsafe_sub(D, D_prev)
            else:
                diff = unsafe_sub(D_prev, D)
            if diff * 10**14 / 10**18 < max(10**16 / 10**18, D):  # Could reduce precision for gas efficiency here
                # Test that we are safe with the next newton_y
                for _x in x:
                    frac: uint256 = _x * PRECISION / D
                    assert (frac > 10**16 / 10**18 - 1) and (frac < 10**20 / 10**18 + 1)  # dev: unsafe values x[i]
                return D

        raise "Did not converge"

    def newton_y_bigint(self, ANN: uint256, gamma: uint256, x: uint256_N_COINS, D: uint256, i: int) -> uint256:
        """
        print("\n newton_y_bigint")
        #print(f"min A: {MIN_A:,.12f}")
        #print(f"max A: {MAX_A:,.12f}")
        print(f"A: {ANN:,.12f}")
        print(f"gamma: {gamma:,.6f}")
        print(f"x[0]: {x[0]:,.6f}")
        print(f"x[1]: {x[1]:,.6f}")
        print(f"i: {i}")
        """
        # Convert to bigints
        ANN *= 10**18
        gamma *= 10**18
        x[0] *= 10**18
        x[1] *= 10**18
        D *= 10**18
        """
        Calculating x[i] given other balances x[0..N_COINS-1] and invariant D
        ANN = A * N**N
        """
        # Safety checks
        assert ANN > MIN_A * 10**18 - 1 and ANN < MAX_A * 10**18 + 1  # dev: unsafe values A
        assert gamma > MIN_GAMMA * 10**18 - 1 and gamma < MAX_GAMMA * 10**18 + 1  # dev: unsafe values gamma
        #print(f"D: {D:,.2f}")
        assert D > 10**17 - 1 and D < 10**15 * 10**18 + 1 # dev: unsafe values D

        x_j: uint256 = x[1 - i]
        y: uint256 = D**2 / (x_j * N_COINS**2)
        K0_i: uint256 = (10**18 * N_COINS) * x_j / D
        # S_i = x_j

        # frac = x_j * 1e18 / D => frac = K0_i / N_COINS
        assert (K0_i > 10**16*N_COINS - 1) and (K0_i < 10**20*N_COINS + 1)  # dev: unsafe values x[i]

        # x_sorted: uint256[N_COINS] = x
        # x_sorted[i] = 0
        # x_sorted = self.sort(x_sorted)  # From high to low
        # x[not i] instead of x_sorted since x_soted has only 1 element

        convergence_limit: uint256 = max(max(x_j / 10**14, D / 10**14), 100)

        __g1k0: uint256 = gamma + 10**18
        #print(f"__g1k0", __g1k0)

        for j in range(NEWTON_MAX_ITERATIONS):
            y_prev: uint256 = y

            K0: uint256 = unsafe_div(K0_i * y * N_COINS, D)
            S: uint256 = x_j + y
            #print(f"K0", K0)
            #print(f"S", S)

            _g1k0: uint256 = __g1k0
            if _g1k0 > K0:
                _g1k0 = unsafe_sub(_g1k0, K0) + 1
            else:
                _g1k0 = unsafe_sub(K0, _g1k0) + 1

            #print(f"_g1k0", _g1k0)

            # D / (A * N**N) * _g1k0**2 / gamma**2
            mul1: uint256 = unsafe_div(unsafe_div(unsafe_div(10**18 * D, gamma) * _g1k0, gamma) * _g1k0 * A_MULTIPLIER, ANN)
            #print(f"mul1", mul1)

            # 2*K0 / _g1k0
            mul2: uint256 = unsafe_div(10**18 + (2 * 10**18) * K0, _g1k0)
            #print(f"mul2", mul2)

            yfprime: uint256 = 10**18 * y + S * mul2 + mul1
            _dyfprime: uint256 = D * mul2
            if yfprime < _dyfprime:
                y = unsafe_div(y_prev, 2)
                continue
            else:
                yfprime = unsafe_sub(yfprime, _dyfprime)
            fprime: uint256 = yfprime / y
            #print(f"fprime", fprime)

            # y -= f / f_prime;  y = (y * fprime - f) / fprime
            # y = (yfprime + 10**18 * D - 10**18 * S) // fprime + mul1 // fprime * (10**18 - K0) // K0
            y_minus: uint256 = mul1 / fprime
            #print(f"y_minus", y_minus)
            y_plus: uint256 = (yfprime + 10**18 * D) / fprime + y_minus * 10**18 / K0
            #print(f"y_plus ", y_plus)
            y_minus += 10**18 * S / fprime
            #print(f"y_minus", y_minus)

            if y_plus < y_minus:
                y = unsafe_div(y_prev, 2)
            else:
                y = unsafe_sub(y_plus, y_minus)

            diff: uint256 = 0
            if y > y_prev:
                diff = unsafe_sub(y, y_prev)
            else:
                diff = unsafe_sub(y_prev, y)
            #print(f"diff", diff)
            if diff < max(convergence_limit, unsafe_div(y, 10**14)):
                frac: uint256 = unsafe_div(y * 10**18, D)
                assert (frac > 10**16 - 1) and (frac < 10**20 + 1)  # dev: unsafe value for y
                #print(f"y: {y:,.2f}")
                return y / 10**18

        print(f"y_prev: {y_prev / 10**18:,.12f}")
        print(f"y     : {y / 10**18:,.12f}")
        print(f"diff:   {diff / 10**18:,.12f}")
        print(f"convergence_limit: {convergence_limit / 10**18:,.12f}")
        raise "Did not converge"

    def newton_y(self, ANN: uint256, gamma: uint256, x: uint256_N_COINS, D: uint256, i: int) -> uint256:
        #print("\n newton_y")
        #print(f"ANN: {rANN}")
        #print(f"gamma: {gamma:,.2f}")
        #print(f"x: {x[0]:,.6f}")
        #print(f"y: {x[1]:,.6f}")
        #print(f"D: {D:,.6f}")
        #print(f"i: {i}")
        """
        Calculating x[i] given other balances x[0..N_COINS-1] and invariant D
        ANN = A * N**N
        """
        # Safety checks
        assert ANN > MIN_A - 1 and ANN < MAX_A + 1  # dev: unsafe values A
        assert gamma > MIN_GAMMA - 1 and gamma < MAX_GAMMA + 1  # dev: unsafe values gamma
        assert D > 10**17 / 10**18 - 1 and D < 10**15 * PRECISION + 1 # dev: unsafe values D

        x_j: uint256 = x[1 - i]
        y: uint256 = D**2 / (x_j * N_COINS**2)
        K0_i: uint256 = (PRECISION * N_COINS) * x_j / D
        # S_i = x_j
        #print(f"K0_i: {K0_i:,.6f}")

        # frac = x_j * 1e18 / D => frac = K0_i / N_COINS
        assert (K0_i >= 10**16 / 10**18 *N_COINS) and (K0_i <= 10**20 / 10**18*N_COINS)  # dev: unsafe values x[i]

        # x_sorted: uint256_N_COINS = x
        # x_sorted[i] = 0
        # x_sorted = self.sort(x_sorted)  # From high to low
        # x[not i] instead of x_sorted since x_soted has only 1 element

        convergence_limit: uint256 = max(max(x_j / 10**14, D / 10**14), 100  / 10**18)
        #print(f"convergence_limit: {convergence_limit:,.18f}")

        __g1k0: uint256 = gamma + PRECISION
        #print(f"__g1k0: {__g1k0:,.6f}")

        for j in range(255):
            y_prev: uint256 = y

            K0: uint256 = unsafe_div(K0_i * y * N_COINS, D)
            S: uint256 = x_j + y
            #print(f"K0: {K0:,.6f}")
            #print(f"S: {S:,.6f}")

            _g1k0: uint256 = __g1k0
            if _g1k0 > K0:
                _g1k0 = unsafe_sub(_g1k0, K0) + 1 / 1e18
            else:
                _g1k0 = unsafe_sub(K0, _g1k0) + 1 / 1e18

            #print(f"_g1k0: {_g1k0:,.6f}")

            # D / (A * N**N) * _g1k0**2 / gamma**2
            # X * _g1k0 / ANN
            mul1: uint256 = unsafe_div(unsafe_div(unsafe_div(PRECISION * D, gamma) * _g1k0, gamma) * _g1k0 * A_MULTIPLIER, ANN) / 10**18
            #print(f"mul1: {mul1:,.6f}")

            # 2*K0 / _g1k0
            mul2: uint256 = unsafe_div(PRECISION / 10**18 + (2 * PRECISION) * K0, _g1k0)
            #print(f"mul2: {mul2:,.6f}")

            yfprime: uint256 = PRECISION * y + S * mul2 + mul1
            _dyfprime: uint256 = D * mul2
            if yfprime < _dyfprime:
                y = unsafe_div(y_prev, 2)
                continue
            else:
                yfprime = unsafe_sub(yfprime, _dyfprime)
            # (y + S * mul2 + mul1 - D * mul2) / y
            fprime: uint256 = yfprime / y
            #print(f"fprime: {fprime:,.6f}")

            # y -= f / f_prime;  y = (y * fprime - f) / fprime
            # y = (yfprime + 10**18 * D - 10**18 * S) // fprime + mul1 // fprime * (10**18 - K0) // K0
            y_minus: uint256 = mul1 / fprime
            #print(f"y_minus: {y_minus:,.6f}")
            y_plus: uint256 = (yfprime + PRECISION * D) / fprime + y_minus * PRECISION / K0
            #print(f"y_plus: {y_plus:,.6f}")
            y_minus += PRECISION * S / fprime
            #print(f"y_minus: {y_minus:,.6f}")

            if y_plus < y_minus:
                y = unsafe_div(y_prev, 2)
            else:
                y = unsafe_sub(y_plus, y_minus)

            diff: uint256 = 0
            if y > y_prev:
                diff = unsafe_sub(y, y_prev)
            else:
                diff = unsafe_sub(y_prev, y)
            if diff < max(convergence_limit, unsafe_div(y, 10**14)):
                frac: uint256 = unsafe_div(y * PRECISION, D)
                #"""
                #print(f"diff: {diff:,.18f}")
                #print(f"convergence_limit: {convergence_limit:,.18f}")
                #print(f"D: {D:,.6f}")
                #print(f"frac: {frac:,.6f}")
                #print(f"min: {(10**16 - 1) / 10**18:,.6f}")
                #print(f"max: {(10**20 + 1) / 10**18:,.6f}")
                #print(f"y: {y:,.6f}")
                #"""
                assert (frac > (10**16 - 1) / 10**18) and (frac < (10**20 + 1) / 10**18)  # dev: unsafe value for y
                return y
            #print(f"diff: {diff:,.18f}")

        raise "Did not converge"


    def _A_gamma(self) -> List[float]:
        return [self.future_A_gamma[0], self.future_A_gamma[1]]

    def halfpow(self, power: uint256) -> uint256:
        """
        1e18 * 0.5 ** (power/1e18)
        """
        return 0.5 ** power

    #@view
    def xp(self) -> uint256_N_COINS:
        return [self.balances[0] * PRECISIONS[0],
                unsafe_div(self.balances[1] * PRECISIONS[1] * self.price_scale, PRECISION)]

    # modifies self.balances
    # modifies self.xcp_profit
    # modifies self.D
    # modifies self.virtual_price
    # modifies self.xcp_profit_a
    def _claim_admin_fees(self):
        #print(" -- _claim_admin_fees")
        A_gamma: List[float] = self._A_gamma()

        xcp_profit: uint256 = self.xcp_profit
        xcp_profit_a: uint256 = self.xcp_profit_a

        # Gulp here
        #_coins: address[N_COINS] = coins
        for i in range(N_COINS):
            #self.balances[i] = ERC20(_coins[i]).balanceOf(self)
            if abs(self.balances[i] - self.coins[i].balance_of(self.pool_account)) > 1e-5:
                print("Balances mismatch:")
                print(f"real balance[{i}]: {self.balances[i]:,.2f}")
                print(f"int balance[{i}]:  {self.coins[i].balance_of(self.pool_account):,.2f}")
            self.balances[i] = self.coins[i].balance_of(self.pool_account)

        vprice: uint256 = self.virtual_price

        if xcp_profit > xcp_profit_a:
            fees: uint256 = unsafe_div((xcp_profit - xcp_profit_a) * self.admin_fee, 2)
            if fees > 0:
                receiver: address = self.admin_fee_receiver
                if receiver != "":
                    frac: uint256 = vprice * PRECISION / (vprice - fees) - PRECISION
                    #claimed: uint256 = CurveToken(token).mint_relative(receiver, frac)
                    claimed: uint256 = self.lp_token.mint(receiver, frac)
                    xcp_profit -= unsafe_mul(fees, 2)
                    self.xcp_profit = xcp_profit
                    #log ClaimAdminFee(receiver, claimed)

        #total_supply: uint256 = CurveToken(token).totalSupply()
        total_supply: uint256 = self.lp_token.total_supply

        # Recalculate D b/c we gulped
        D: uint256 = self.newton_D(A_gamma[0], A_gamma[1], self.xp())
        self.D = D

        self.virtual_price = PRECISION * self.get_xcp(D) / total_supply

        if xcp_profit > xcp_profit_a:
            self.xcp_profit_a = xcp_profit

        return

    # modifies self.last_prices
    # modifies self._price_oracle
    # modifies self.xcp_profit
    # modifies self.not_adjusted
    # modifies self.price_scale <-- !!
    # modifies self.D <-- !!
    # modifies self.virtual_price
    # calls self._claim_admin_fees
    def tweak_price(self, A_gamma: List[float], _xp: uint256_N_COINS, p_i: uint256, new_D: uint256):
        price_oracle: uint256 = self._price_oracle
        last_prices: uint256 = self.last_prices
        price_scale: uint256 = self.price_scale
        last_prices_timestamp: uint256 = self.last_prices_timestamp
        p_new: uint256 = 0

        """
        print("\n --- Tweak price !!! ---")
        print(f"A: {A_gamma[0]:,.18f}")
        print(f"gamma: {A_gamma[1]:,.6f}")
        print(f"x: {_xp[0]:,.2f}")
        print(f"y: {_xp[1]:,.2f}")
        print(f"p_i: {p_i:,.2f}")
        print(f"new_D: {new_D:,.12f}")
        print(f"price_oracle: {price_oracle:,.2f}")
        print(f"last_prices: {last_prices:,.2f}")
        print(f"price_scale: {price_scale:,.2f}")
        """

        if last_prices_timestamp < self.block_timestamp:
            # MA update required
            ma_half_time: uint256 = self.ma_half_time
            alpha: uint256 = self.halfpow(unsafe_div(unsafe_mul(self.block_timestamp - last_prices_timestamp, PRECISION), ma_half_time))
            price_oracle = unsafe_div(last_prices * (PRECISION - alpha) + price_oracle * alpha, PRECISION)
            #print(f"price_oracle: {price_oracle:,.2f}")
            self._price_oracle = price_oracle
            self.last_prices_timestamp = self.block_timestamp

        D_unadjusted: uint256 = new_D  # Withdrawal methods know new D already
        if new_D == 0:
            # We will need this a few times (35k gas)
            D_unadjusted = self.newton_D_bigint(A_gamma[0], A_gamma[1], _xp.copy())
            """
            print(f"_xp[0]: {_xp[0]:,.6f}")
            print(f"_xp[1]: {_xp[1]:,.6f}")
            print(f"D_unadjusted: {D_unadjusted:,.6f}")
            """

        if p_i > 0:
            last_prices = p_i

        else:
            # calculate real prices
            __xp: uint256_N_COINS = _xp.copy()
            dx_price: uint256 = unsafe_div(__xp[0], 10**6)
            __xp[0] += dx_price
            last_prices = price_scale * dx_price / (_xp[1] - self.newton_y_bigint(A_gamma[0], A_gamma[1], __xp.copy(), D_unadjusted, 1))

        self.last_prices = last_prices

        #total_supply: uint256 = CurveToken(token).totalSupply()
        total_supply: uint256 = self.lp_token.total_supply
        old_xcp_profit: uint256 = self.xcp_profit
        old_virtual_price: uint256 = self.virtual_price

        # Update profit numbers without price adjustment first
        xp: uint256_N_COINS = [unsafe_div(D_unadjusted, N_COINS), D_unadjusted * PRECISION / (N_COINS * price_scale)]
        xcp_profit: uint256 = PRECISION
        virtual_price: uint256 = PRECISION

        if old_virtual_price > 0:
            xcp: uint256 = self.geometric_mean(xp.copy(), True)
            virtual_price = PRECISION * xcp / total_supply
            """
            print(f"xp[0]: {xp[0]:,.2f}")
            print(f"xp[1]: {xp[1]:,.2f}")
            print(f"xcp: {xcp:,.2f}")
            print(f"total_supply: {total_supply:,.2f}")
            """
            xcp_profit = old_xcp_profit * virtual_price / old_virtual_price

            t: uint256 = self.future_A_gamma_time
            #if virtual_price < old_virtual_price and t == 0:
            # To avoid rounding issues:
            if virtual_price + 1e-10 < old_virtual_price and t == 0:
                print(f"virtual_price: {virtual_price:,.18f}")
                print(f"old_virtual_price: {old_virtual_price:,.18f}")
                print(f"diff: {old_virtual_price - virtual_price:,.18f}")
                print(f"\n\n -- LOSS !!! -- \n\n")
                raise "Loss"
            if t == 1:
                self.future_A_gamma_time = 0

        self.xcp_profit = xcp_profit

        norm: uint256 = price_oracle * PRECISION / price_scale
        if norm > PRECISION:
            norm = unsafe_sub(norm, PRECISION)
        else:
            norm = unsafe_sub(PRECISION, norm)
        adjustment_step: uint256 = max(self.adjustment_step, unsafe_div(norm, 10))

        needs_adjustment: bool = self.not_adjusted
        # if not needs_adjustment and (virtual_price-10**18 > (xcp_profit-10**18)/2 + self.allowed_extra_profit):
        # (re-arrange for gas efficiency)
        if not needs_adjustment and (virtual_price * 2 - PRECISION > xcp_profit + unsafe_mul(self.allowed_extra_profit, 2)) and (norm > adjustment_step) and (old_virtual_price > 0):
            needs_adjustment = True
            self.not_adjusted = True

        if needs_adjustment:
            if norm > adjustment_step and old_virtual_price > 0:
                p_new = unsafe_div(price_scale * (norm - adjustment_step) + adjustment_step * price_oracle, norm)

                # Calculate balances*prices
                xp = [_xp[0], _xp[1] * p_new / price_scale]

                # Calculate "extended constant product" invariant xCP and virtual price
                D: uint256 = self.newton_D_bigint(A_gamma[0], A_gamma[1], xp.copy())
                xp = [unsafe_div(D, N_COINS), D * PRECISION / (N_COINS * p_new)]
                # We reuse old_virtual_price here but it's not old anymore
                old_virtual_price = PRECISION * self.geometric_mean(xp, True) / total_supply

                # Proceed if we've got enough profit
                # if (old_virtual_price > 10**18) and (2 * (old_virtual_price - 10**18) > xcp_profit - 10**18):
                if (old_virtual_price > PRECISION) and (2 * old_virtual_price - PRECISION > xcp_profit):
                    self.price_scale = p_new
                    self.D = D
                    self.virtual_price = old_virtual_price

                    return

                else:
                    self.not_adjusted = False

                    # Can instead do another flag variable if we want to save bytespace
                    self.D = D_unadjusted
                    self.virtual_price = virtual_price
                    self._claim_admin_fees()

                    return

        # If we are here, the price_scale adjustment did not happen
        # Still need to update the profit counter and D
        self.D = D_unadjusted
        self.virtual_price = virtual_price

        # norm appeared < adjustment_step after
        if needs_adjustment:
            self.not_adjusted = False
            self._claim_admin_fees()

    # modifies self.balances
    # calls self.tweak_price
    def _exchange(self, sender: address, i: uint256, j: uint256, dx: uint256, min_dy: uint256,
                  receiver: address, debug=False) -> (uint256, uint256):
        #print(f"_exchange({i}, {j}, {dx:,.6f}, {min_dy:,.2f})")
        assert not self.is_killed  # dev: the pool is killed
        assert i != j  # dev: coin index out of range
        assert i < N_COINS  # dev: coin index out of range
        assert j < N_COINS  # dev: coin index out of range
        assert dx > 0  # dev: do not exchange 0 coins

        A_gamma: List[float] = self._A_gamma()
        xp: uint256_N_COINS = self.balances.copy()
        if debug:
            print(f"xp[0]: {xp[0]:,.6f}")
            print(f"xp[1]: {xp[1]:,.6f}")
            print(f"dx: {dx:,.6f}")
        p: uint256 = 0
        dy: uint256 = 0

        #_coins = self.coins

        y: uint256 = xp[j]
        x0: uint256 = xp[i]
        xp[i] = x0 + dx
        self.balances[i] = xp[i]

        price_scale: uint256 = self.price_scale

        xp = [xp[0] * PRECISIONS[0], xp[1] * price_scale * PRECISIONS[1] / PRECISION]

        prec_i: uint256 = PRECISIONS[0]
        prec_j: uint256 = PRECISIONS[1]
        if i == 1:
            prec_i = PRECISIONS[1]
            prec_j = PRECISIONS[0]

        # In case ramp is happening
        """
        t: uint256 = self.future_A_gamma_time
        if t > 0:
            x0 *= prec_i
            if i > 0:
                x0 = x0 * price_scale / PRECISION
            x1: uint256 = xp[i]  # Back up old value in xp
            xp[i] = x0
            self.D = self.newton_D_bigint(A_gamma[0], A_gamma[1], xp.copy())
            xp[i] = x1  # And restore
            if self.block_timestamp >= t:
                self.future_A_gamma_time = 1
        """

        #dy = xp[j] - self.newton_y_bigint(A_gamma[0], A_gamma[1], xp.copy(), self.D, j)
        n = self.newton_y_bigint(A_gamma[0], A_gamma[1], xp.copy(), self.D, j)
        dy = xp[j] - n
        if debug:
            print(f"xp[j]: {xp[j]:,.2f}")
            print(f"n: {n:,.2f}")
            print(f"dy: {dy:,.2f}")
        # Not defining new "y" here to have less variables / make subsequent calls cheaper
        xp[j] -= dy
        dy -= 1

        if j > 0:
            dy = dy * PRECISION / price_scale
        dy /= prec_j

        #dy -= self._fee(xp) * dy
        fee_amount = self._fee(xp) * dy
        if debug:
            print(f"dy: {dy:,.6f}")
            print(f"fee: {self._fee(xp):,.6f}")
            print(f"fee amt: {fee_amount:,.6f}")
        dy -= fee_amount
        if dy < 0:
            return 0, 0
        if debug:
            print(f"dy: {dy:,.6f}")
            print(f"min dy: {min_dy:,.6f}")
        assert dy >= min_dy, "Slippage"
        y -= dy

        self.balances[j] = y

        #assert ERC20(_coins[i]).transferFrom(sender, self, dx)
        #assert ERC20(_coins[j]).transfer(receiver, dy)
        self.coins[i].transfer(sender, self.pool_account, dx)
        self.coins[j].transfer(self.pool_account, receiver, dy)

        y *= prec_j
        if j > 0:
            y = y * price_scale / PRECISION
        xp[j] = y

        # Calculate price
        if dx > 10**5 / 10**18 and dy > 10**5 / 10**18:
            _dx: uint256 = dx * prec_i
            _dy: uint256 = dy * prec_j
            if i == 0:
                p = _dx * PRECISION / _dy
            else:  # j == 0
                p = _dy * PRECISION / _dx

        self.tweak_price(A_gamma, xp, p, 0)

        #log TokenExchange(sender, i, dx, j, dy)

        return dy, fee_amount


    def swap_A_for_B(self, account, input_amount):
        try:
            assert input_amount >= 0.0
        except:
            print(f"User:   {account}")
            print(f"amount: {input_amount:,.2f}")
            raise RuntimeError('Error, swapping negative amount!')

        if input_amount == 0.0:
            return 0.0
        # checked on transfer
        #assert self.token_A.balance_of(self.account) > amount

        output_amount, fee_amount = self._exchange(account, 0, 1, input_amount, 0, account)
        """
        print(f"in:  {input_amount:,.2f}")
        print(f"out: {output_amount:,.2f}")
        print(f"fee: {fee_amount:,.2f}")
        print(f"effective price: {input_amount / output_amount:,.6f}")
        print(f"price w/o fees:  {input_amount / (output_amount + fee_amount):,.6f}")
        """

        self.fees_accrued_B = self.fees_accrued_B + fee_amount

        return output_amount

    def swap_B_for_A(self, account, input_amount):
        try:
            assert input_amount >= 0.0
        except:
            print(f"User:   {account}")
            print(f"amount: {input_amount:,.2f}")
            raise RuntimeError('Error, swapping negative amount!')

        if input_amount == 0.0:
            return 0.0
        # checked on transfer
        #assert self.token_B.balance_of(self.account) > amount

        output_amount, fee_amount = self._exchange(account, 1, 0, input_amount, 0, account)

        self.fees_accrued_A = self.fees_accrued_A + fee_amount

        return output_amount

    def get_xcp(self, D: uint256) -> uint256:
        x: uint256_N_COINS = [unsafe_div(D, N_COINS), D * PRECISION / (self.price_scale * N_COINS)]
        """
        print(f" -- get_xcp")
        print(f"price_scale: {self.price_scale:,.2f}")
        print(f"x[0]: {x[0]:,.2f}")
        print(f"x[1]: {x[1]:,.2f}")
        """
        return self.geometric_mean(x, True)


    def get_A_amount_for_liquidity(self, token_B_amount):
        token_A_reserve = self.token_A_balance()
        token_B_reserve = self.token_B_balance()
        if token_B_reserve == 0:
            return token_B_amount * self.price_scale / PRECISION
        return token_B_amount * token_A_reserve / token_B_reserve
    def get_B_amount_for_liquidity(self, token_A_amount):
        token_A_reserve = self.token_A_balance()
        token_B_reserve = self.token_B_balance()
        if token_A_reserve == 0:
            return token_A_amount * PRECISION / self.price_scale
        return token_A_amount * token_B_reserve / token_A_reserve

    def _calc_token_fee(self, amounts: uint256_N_COINS, xp: uint256_N_COINS) -> uint256:
        #print(f"amounts[0]: {amounts[0]:,.12f}")
        #print(f"amounts[1]: {amounts[1]:,.12f}")
        # fee = sum(amounts_i - avg(amounts)) * fee' / sum(amounts)
        fee: uint256 = self._fee(xp) * N_COINS / (4 * (N_COINS-1))
        #print(f"fee: {fee:,.12f}")
        S: uint256 = 0
        for _x in amounts:
            S += _x
        #print(f"S: {S:,.12f}")
        avg: uint256 = S / N_COINS
        #print(f"avg: {avg:,.12f}")
        Sdiff: uint256 = 0
        for _x in amounts:
            if _x > avg:
                Sdiff += _x - avg
            else:
                Sdiff += avg - _x
        #print(f"Sdiff: {Sdiff:,.12f}")
        #print(f"_ctf: {fee * Sdiff / S + NOISE_FEE:,.12f}")
        return fee * Sdiff / S + NOISE_FEE

    def _add_liquidity(self, amounts: uint256_N_COINS, min_mint_amount: uint256, sender: address,
                       receiver: address) -> (uint256, uint256):
        #print(f"_add_liquidity([{amounts[0]:,.6f}, {amounts[1]:,.6f}], {min_mint_amount:,.2f}, {sender}, {receiver})")
        assert not self.is_killed  # dev: the pool is killed
        assert amounts[0] > 0 or amounts[1] > 0  # dev: no coins to add

        A_gamma: uint256[2] = self._A_gamma()

        #_coins: address[N_COINS] = coins
        _coins = self.coins.copy()

        xp: uint256_N_COINS = self.balances.copy()
        amountsp: uint256_N_COINS = [0, 0]
        xx: uint256_N_COINS = [0, 0]
        d_token: uint256 = 0
        d_token_fee: uint256 = 0
        old_D: uint256 = 0

        xp_old: uint256_N_COINS = xp.copy()

        for i in range(N_COINS):
            bal: uint256 = xp[i] + amounts[i]
            xp[i] = bal
            self.balances[i] = bal
            #print(f"bal {i} (_add_liquidity): {self.balances[i]:,.2f}")
        xx = xp.copy()

        price_scale: uint256 = self.price_scale * PRECISIONS[1]
        xp = [xp[0] * PRECISIONS[0], xp[1] * price_scale / PRECISION]
        xp_old = [xp_old[0] * PRECISIONS[0], xp_old[1] * price_scale / PRECISION]

        for i in range(N_COINS):
            if amounts[i] > 0:
                #assert ERC20(_coins[i]).transferFrom(msg.sender, self, amounts[i])
                _coins[i].transfer(sender, self.pool_account, amounts[i])
                amountsp[i] = xp[i] - xp_old[i]
                """
                print(f"x{i}: {xp[i]:,.2f}")
                print(f"o{i}: {xp_old[i]:,.2f}")
                print(f"a{i}: {amountsp[i]:,.2f}")
                """
        assert amounts[0] > 0 or amounts[1] > 0  # dev: no coins to add

        t: uint256 = self.future_A_gamma_time
        if t > 0:
            old_D = self.newton_D_bigint(A_gamma[0], A_gamma[1], xp_old.copy())
            if self.block_timestamp >= t:
                self.future_A_gamma_time = 1
        else:
            old_D = self.D

        D: uint256 = self.newton_D_bigint(A_gamma[0], A_gamma[1], xp.copy())

        #token_supply: uint256 = CurveToken(token).totalSupply()
        token_supply: uint256 = self.lp_token.total_supply
        if old_D > 0:
            d_token = token_supply * D / old_D - token_supply
        else:
            d_token = self.get_xcp(D)  # making initial virtual price equal to 1
        assert d_token > 0  # dev: nothing minted
        """
        print(f"token_supply: {token_supply:,.2f}")
        print(f"D (add_liquidity): {D:,.2f}")
        print(f"old D: {old_D:,.2f}")
        print(f"d_token: {d_token:,.2f}")
        """

        if old_D > 0:
            d_token_fee = self._calc_token_fee(amountsp, xp) * d_token
            #print(f"d_token: {d_token:,.2f}")
            #print(f"d_token_fee: {d_token_fee:,.6f}")
            d_token -= d_token_fee
            token_supply += d_token
            #CurveToken(token).mint(receiver, d_token)
            self.lp_token.mint(receiver, d_token)

            # Calculate price
            # p_i * (dx_i - dtoken / token_supply * xx_i) = sum{k!=i}(p_k * (dtoken / token_supply * xx_k - dx_k))
            # Simplified for 2 coins
            p: uint256 = 0
            if d_token > 10**5 / 10**18:
                if amounts[0] == 0 or amounts[1] == 0:
                    S: uint256 = 0
                    precision: uint256 = 0
                    ix: uint256 = 0
                    if amounts[0] == 0:
                        S = xx[0] * PRECISIONS[0]
                        precision = PRECISIONS[1]
                        ix = 1
                    else:
                        S = xx[1] * PRECISIONS[1]
                        precision = PRECISIONS[0]
                    S = S * d_token / token_supply
                    p = S * PRECISION / (amounts[ix] * precision - d_token * xx[ix] * precision / token_supply)
                    if ix == 0:
                        p = (PRECISION)**2 / p

            self.tweak_price(A_gamma, xp, p, D)

        else:
            self.D = D
            #print(f"D (add_liquidity): {D:,.2f}")
            self.virtual_price = PRECISION
            self.xcp_profit = PRECISION
            #CurveToken(token).mint(receiver, d_token)
            self.lp_token.mint(receiver, d_token)

        assert d_token >= min_mint_amount, "Slippage"

        #log AddLiquidity(receiver, amounts, d_token_fee, token_supply)

        return d_token, d_token_fee

    def add_liquidity(self, account, token_A_amount, max_token_B_amount):
        token_B_amount = self.get_B_amount_for_liquidity(token_A_amount) * 0.999 # to avoid rounding issues
        """
        print(f"token_A_amount:     {token_A_amount:,.2f}")
        print(f"token_B_amount:     {token_B_amount:,.2f}")
        print(f"max_token_B_amount: {max_token_B_amount:,.2f}")
        """
        assert token_B_amount <= max_token_B_amount

        #print(f"\033[32m add_liquidity: [{token_A_amount:,.2f}, {token_B_amount:,.2f}]\033[0m")
        lp_token_amount, lp_token_fee_amount = self._add_liquidity([token_A_amount, token_B_amount], 0, account, account)

        self.fees_accrued_LP = self.fees_accrued_LP + lp_token_fee_amount

        return token_A_amount, token_B_amount

    def add_liquidity_single_A(self, account, token_A_amount, max_slippage):
        return 0, 0

    def _fee(self, xp: uint256_N_COINS) -> uint256:
        """
        f = fee_gamma / (fee_gamma + (1 - K))
        where
        K = prod(x) / (sum(x) / N)**N
        (all normalized to 1e18)
        """
        fee_gamma: uint256 = self.fee_gamma
        f: uint256 = xp[0] + xp[1]  # sum
        """
        print("_fee")
        print(f"fee_gamma: {fee_gamma:,.6f}")
        print(f"f: {f:,.6f}")
        print(f"fee_gamma+1: {fee_gamma+1:,.6f}")
        print(f"minus: {unsafe_div((PRECISION * N_COINS**N_COINS) * xp[0] / f * xp[1], f):,.6f}")
        print(f"den: {unsafe_add(fee_gamma, PRECISION) - unsafe_div((PRECISION * N_COINS**N_COINS) * xp[0] / f * xp[1], f):,.6f}")
        """
        f = unsafe_mul(fee_gamma, PRECISION) / (
            unsafe_add(fee_gamma, PRECISION) - unsafe_div((PRECISION * N_COINS**N_COINS) * xp[0] / f * xp[1], f)
        )
        """
        print(f"f: {f:,.6f}")
        print(f"mf: {self.mid_fee:,.6f}")
        print(f"of: {self.out_fee:,.6f}")
        print(f"mf*f: {self.mid_fee * f:,.6f}")
        print(f"1-f: {PRECISION - f:,.6f}")
        print(f"of*(1-f): {self.out_fee * (PRECISION - f):,.6f}")
        print("---")
        """
        return unsafe_div(self.mid_fee * f + self.out_fee * (PRECISION - f), PRECISION)

    def get_dy(self, i: int, j: int, dx: uint256, debug: bool = False) -> uint256:
        if debug:
            print("\n\033[93m -- get_dy\033[0m")
            print(f"i: {i}")
            print(f"j: {j}")
            print(f"bal A:  {self.balances[0]:,.2f}")
            print(f"real A: {self.coins[0].balance_of(self.pool_account):,.2f}")
            print(f"bal B:  {self.balances[1]:,.2f}")
            print(f"real B: {self.coins[1].balance_of(self.pool_account):,.2f}")
            print(f"dx: {dx:,.2f}")
            print(f"price_scale: {self.price_scale:,.2f}")
        if self.balances[0] == 0 and self.balances[1] == 0:
            return 0
        assert i != j  # dev: same input and output coin
        assert i < N_COINS  # dev: coin index out of range
        assert j < N_COINS  # dev: coin index out of range

        price_scale: uint256 = self.price_scale * PRECISIONS[1]
        xp: uint256_N_COINS = self.balances.copy()

        A_gamma: uint256[2] = self._A_gamma()
        D: uint256 = self.D
        if debug:
            print(f"D: {D:,.2f}")
        if self.future_A_gamma_time > 0:
            D = self.newton_D_bigint(A_gamma[0], A_gamma[1], self.xp().copy())

        xp[i] += dx
        xp = [xp[0] * PRECISIONS[0], xp[1] * price_scale / PRECISION]
        if debug:
            print(f"xp[0]: {xp[0]:,.2f}")
            print(f"xp[1]: {xp[1]:,.2f}")
            print(f"newton_y_bigint({A_gamma[0]:,.2f}, {A_gamma[1]:,.2f}, {xp[0]:,.2f}, {xp[1]:,.2f}, {D:,.2f}, {j})")

        y: uint256 = self.newton_y_bigint(A_gamma[0], A_gamma[1], xp.copy(), D, j)
        dy: uint256 = xp[j] - y - 1 / 10**18
        if debug:
            print(f"y: {y:,.2f}")
            print(f"dy: {dy:,.2f}")
        xp[j] = y
        if j > 0:
            dy = dy * PRECISION / price_scale
        else:
            dy /= PRECISIONS[0]
        #print(f"dy: {dy:,.2f}")
        dy -= self._fee(xp) * dy
        if debug:
            print(f"dy: {dy:,.18f}")
        assert dy > 0

        return dy

    def save_state(self):
        state = {}
        state["balances"] = self.balances.copy()
        state["price_scale"] = self.price_scale
        state["D"] = self.D
        state["last_prices"] = self.last_prices
        state["_price_oracle"] = self._price_oracle
        state["xcp_profit"] = self.xcp_profit
        state["not_adjusted"] = self.not_adjusted
        state["virtual_price"] = self.virtual_price
        state["xcp_profit_a"] = self.xcp_profit_a

        return state

    def revert_state(self, state, debug=False):
        if debug:
            #"""
            print(f"self.balances[0]: {self.balances[0]:,.2f}")
            print(f"balances[0]: {balances[0]:,.2f}")
            print(f"self.balances[1]: {self.balances[1]:,.2f}")
            print(f"balances[1]: {balances[1]:,.2f}")
            print(f"self.price_scale: {self.price_scale:,.2f}")
            print(f"price_scale: {price_scale:,.2f}")
            print(f"self.D: {self.D:,.2f}")
            print(f"D: {D:,.2f}")
            print(f"self.last_prices: {self.last_prices:,.2f}")
            print(f"last_prices: {last_prices:,.2f}")
            print(f"self._price_oracle: {self._price_oracle:,.2f}")
            print(f"_price_oracle: {_price_oracle:,.2f}")
            print(f"self.xcp_profit: {self.xcp_profit:,.2f}")
            print(f"xcp_profit: {xcp_profit:,.2f}")
            print(f"self.not_adjusted: {self.not_adjusted:,.2f}")
            print(f"not_adjusted: {not_adjusted:,.2f}")
            print(f"self.virtual_price: {self.virtual_price:,.2f}")
            print(f"virtual_price: {virtual_price:,.2f}")
            print(f"self.xcp_profit_a: {self.xcp_profit_a:,.2f}")
            print(f"xcp_profit_a: {xcp_profit_a:,.2f}")
            #"""
        self.balances[0] = state["balances"][0]
        self.balances[1] = state["balances"][1]
        self.price_scale = state["price_scale"]
        self.D = state["D"]
        self.last_prices = state["last_prices"]
        self._price_oracle = state["_price_oracle"]
        self.xcp_profit = state["xcp_profit"]
        self.not_adjusted = state["not_adjusted"]
        self.virtual_price = state["virtual_price"]
        self.xcp_profit_a = state["xcp_profit_a"]

        return

    def undo_transfers(self, dx, dy, output_amount):
        # Undo transfers
        if dx > 0:
            self.coins[0].transfer(self.pool_account, TMP_ACCOUNT, dx)
            self.coins[1].transfer(TMP_ACCOUNT, self.pool_account, output_amount)
        if dy > 0:
            self.coins[1].transfer(self.pool_account, TMP_ACCOUNT, dy)
            self.coins[0].transfer(TMP_ACCOUNT, self.pool_account, output_amount)
            self.coins[1].burn(TMP_ACCOUNT, dy)

        return

    # dx is always token A (LUSD), never B (bLUSD), no matter what the order of i,j is
    def get_spot_price(self, i, j, dx = 0, dy = 0, debug=False):
        # A good trade off to reduce both slippage and error due to Newton method (2% of the balance in the pool):
        if self.balances[i] == 0:
            return 0
        sample_amount = self.balances[i] * 0.02
        if debug:
            print("\033[35m\n -- get_spot_price\033[0m")
            print(f"dx: {dx:,.2f}")
        assert dx == 0 or dy == 0
        # Save state
        if dx > 0 or dy > 0:
            state = self.save_state()

        price_before = self.get_dy(i, j, sample_amount) / sample_amount
        if debug:
            print(f"price before!:  {price_before:,.6f}")
            print(f"price_scale b4: {self.price_scale:,.6f}")
        exchange_price = 0
        if dx > 0:
            output_amount, _ = self._exchange(TMP_ACCOUNT, 0, 1, dx, 0, TMP_ACCOUNT)
            exchange_price = dx / output_amount
            if debug:
                print(f"output_amount (dy): {output_amount:,.6f}")
                print(f"exchange_price: {exchange_price:,.6f}")
        if dy > 0:
            # we need to mint bLUSD to simulate exchange!
            self.coins[1].mint(TMP_ACCOUNT, dy)
            output_amount, _ = self._exchange(TMP_ACCOUNT, 1, 0, dy, 0, TMP_ACCOUNT)
            exchange_price = dy / output_amount
            if debug:
                print(f"output_amount (dx): {output_amount:,.6f}")
                print(f"exchange_price: {exchange_price:,.6f}")

        #print("\033[35m\n -- get_spot_price (cont)\033[0m")
        # Tweak price can mess things up, making the exchange have a higher price than the final spot price
        price = max(self.get_dy(i, j, sample_amount, debug) / sample_amount, exchange_price)
        if debug:
            print(f"price: {price:,.6f}")
            print(f"price_scale: {self.price_scale:,.6f}")

        if dx > 0 or dy > 0:
            # undo state
            self.revert_state(state)
            # Undo transfers
            self.undo_transfers(dx, dy, output_amount)


        price_after = self.get_dy(i, j, sample_amount) / sample_amount
        if debug:
            print(f"price after!: {price_after:,.2f}")
        assert price_before == price_after

        return price

    def get_token_A_price(self, dx = 0, dy = 0):
        return self.get_spot_price(0, 1, dx, dy)

    def get_token_B_price(self, dx = 0, dy = 0, debug=False):
        return self.get_spot_price(1, 0, dx, dy, debug)

    # Given a target token B price, returns the amount of token A that needs to be swapped to increase
    # current token B price to the desired target
    def get_input_A_amount_from_target_price_B(self, target_price, debug=False):
        if self.balances[1] == 0:
            return 0
        MAX_STEPS = 100
        if debug:
            print(" \n-------------------- ")
            print(" -- get_input_A_amount_from_target_price_B")
            print(f"target_price: {target_price:,.6f}")
        initial_price = self.get_token_B_price(0, 0, debug)
        if debug:
            print(f"initial_price: {initial_price:,.2f}")
        if target_price <= initial_price:
            return 0
        step_amount = max(4 * self.token_A_balance() / MAX_STEPS * (target_price / initial_price - 1), 100)
        input_amount = 0
        next_price = initial_price
        if debug:
            #"""
            print(" -- get_input_A_amount_from_target_price_B (cont.)")
            print(f"bal[0]: {self.balances[0]:,.2f}")
            print(f"bal[1]: {self.balances[1]:,.2f}")
            print(f"A: {self.token_A_balance():,.2f}")
            print(f"B: {self.token_B_balance():,.2f}")
            print(f"initial_price: {initial_price:,.6f}")
            print(f"step: {step_amount:,.2f}")
            print(f"price_scale: {self.price_scale:,.6f}")
            #print(f"last_prices: {self.last_prices:,.6f}")
            #"""
        step = 0
        while target_price > next_price:
            input_amount += step_amount
            next_price = self.get_token_B_price(input_amount, 0)
            if debug:
                print(f"Step: {step}")
                print(f"next_price: {next_price:,.6f}")
                print(f"input_amount: {input_amount:,.2f}")

            step = step + 1
            assert step < MAX_STEPS

        # _exchange and get_dy already include fees, so no need to discount them
        return input_amount - step_amount

    # Slippage

    # slippage from input
    def get_slippage_from_input(self, initial_price, i, j, input_amount, debug=False):
        if debug:
            print(f"\033[92m\n -- get_slippage_from_input ({i}, {j})\033[0m")
            print(f"initial_price: {initial_price:,.2f}")
            print(f"input_amount:  {input_amount:,.2f}")

        # Save state
        state = self.save_state()

        if i > j:
            dx = 0
            dy = input_amount
            # we need to mint bLUSD to simulate exchange!
            self.coins[1].mint(TMP_ACCOUNT, dy)
            output_amount, _ = self._exchange(TMP_ACCOUNT, 1, 0, dy, 0, TMP_ACCOUNT, debug)
        else:
            dx = input_amount
            dy = 0
            output_amount, _ = self._exchange(TMP_ACCOUNT, 0, 1, dx, 0, TMP_ACCOUNT, debug)

        if debug:
            print(f"output_amount (dy): {output_amount:,.6f}")

        slippage = 1 - output_amount / (input_amount * initial_price)

        # Undo state
        self.revert_state(state)
        self.undo_transfers(dx, dy, output_amount)

        if debug:
            print(f"\033[92m -- get_slippage_from_input ({i}, {j}) (cont)\033[0m")
            print(f"slippage: {slippage:.3%}")

        return slippage

    def get_slippage_from_input_A(self, input_amount, debug=False):
        initial_price = self.get_token_A_price()
        if initial_price == 0:
            return 0
        return self.get_slippage_from_input(initial_price, 0, 1, input_amount, debug)

    def get_slippage_from_input_B(self, input_amount, debug=False):
        initial_price = self.get_token_B_price()
        if initial_price == 0:
            return 0
        return self.get_slippage_from_input(initial_price, 1, 0, input_amount, debug)

    def get_input_for_max_slippage(self, initial_price, max_slippage, i, j, debug):
        input_amount = self.balances[i] / 5
        if debug:
            print(f"\n -- get_input_for_max_slippage ({i}, {j})")
            print(f"initial_price: {initial_price:,.2f}")
            print(f"input_amount: {input_amount:,.2f}")
            print(f"max_slippage: {max_slippage:.3%}")
            print(f"bal[{i}]: {self.balances[i]:,.2f}")
            print(f"bal[{j}]: {self.balances[j]:,.2f}")
            print(f"A bal: {self.token_A_balance():,.2f}")
            print(f"B bal: {self.token_B_balance():,.2f}")
        slippage = self.get_slippage_from_input(initial_price, i, j, input_amount, debug)
        step = 0
        while slippage > max_slippage:
            step = step + 1
            slippage = self.get_slippage_from_input(initial_price, i, j, input_amount, debug)
            if debug:
                print(f"\nStep {step}")
                print(f"input: {input_amount:,.2f}")
                print(f"slippage: {slippage:.3%}")
            input_amount = input_amount * max(0.5, min(0.8, 0.8 - 0.3 * slippage))
            # TODO:
            #assert step < 30
            if step >=30:
                print("\033[31m -- max iterations reached in get_input_for_max_slippage\033[0m")
                return 0

        if debug:
            print("")
            print(f"\033[32m Final slippage: {slippage:.3%} \033[0m")
            print(f"\033[33m Final input:   {input_amount:,.2f} \033[0m")
            print("")

        return input_amount

    def get_input_A_for_max_slippage(self, max_slippage, token_A_offset, token_B_offset, debug=False):
        initial_price = self.get_token_A_price()
        return self.get_input_for_max_slippage(initial_price, max_slippage, 0, 1, debug)

    def get_input_B_for_max_slippage(self, max_slippage, token_A_offset, token_B_offset, debug=False):
        if debug:
            print("\n -- get_input_B_for_max_slippage")
            print(f"max_slippage: {max_slippage:.3%}")
            print(f"offset A: {token_A_offset:,.2f}")
            print(f"offset B: {token_B_offset:,.2f}")
        initial_price = self.get_token_B_price()
        if debug:
            print(f"initial price: {initial_price:,.2f}")
        return self.get_input_for_max_slippage(initial_price, max_slippage, 1, 0, debug)

    # slippage from output (not needed)
    """
    def get_output_for_max_slippage(self, initial_price, max_slippage, token_A, token_B, token_A_offset, token_B_offset):
        #print("")
        #print("-- get input price:")
        output_amount = token_B.balance_of(self.pool_account) / 2
        slippage = self.get_slippage_from_output(initial_price, output_amount, token_A, token_B, token_A_offset, token_B_offset)
        step = 0
        while slippage > max_slippage:
            step = step + 1
            output_amount = output_amount * 0.8
            slippage = self.get_slippage_from_output(initial_price, output_amount, token_A, token_B, token_A_offset, token_B_offset)
            #assert step < 30
            if step > 30:
                #print(self)
                return 0

        assert slippage > 0

        return output_amount

    def get_output_A_for_max_slippage(self, max_slippage, token_A_offset, token_B_offset):
        initial_price = self.get_token_B_price()
        return self.get_output_for_max_slippage(initial_price, max_slippage, self.token_B, self.token_A, token_A_offset, token_B_offset)

    def get_output_B_for_max_slippage(self, max_slippage, token_A_offset, token_B_offset):
        initial_price = self.get_token_A_price()
        return self.get_output_for_max_slippage(initial_price, max_slippage, self.token_A, self.token_B, token_A_offset, token_B_offset)
    """
