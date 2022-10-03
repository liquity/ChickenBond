import math
import numpy as np
import random

from lib.constants import *

# Testers

class TesterInterface():
    def __init__(self):
        self.name = ""
        self.iterations = ITERATIONS

        self.price_max_value = 200
        self.apr_min_value = -20
        self.apr_max_value = 200

        self.plot_prefix = ''
        self.plot_file_description = ''

        self.chicken_in_counter = 0
        self.chicken_out_counter = 0

        return

    def init(self, chicks):
        pass

    def prefixes_getter(self):
        pass

    def get_fair_price(self, chicken):
        pass

    def get_btkn_spot_price(self, chicken):
        pass

    def get_natural_rate(self, natural_rate, iteration):
        pass

    def get_bonding_apr_spot(self, chicken):
        pass

    def get_bonding_apr_twap(self, chicken, data, iteration):
        pass

    def get_btkn_apr_spot(self, chicken, data, iteration):
        pass

    def get_btkn_apr_twap(self, chicken, data, iteration):
        pass

    def get_btkn_apr(self, chicken, data, iteration):
        pass

    def get_backing_ratio(self, chicken):
        pass

    def get_avg_outstanding_bond_age(self, chicks, iteration):
        pass

    def set_accrual_param(self, new_value):
        pass

    def distribute_yield(self, chicken, chicks, iteration):
        pass

    def bond(self, chicken, chicks, iteration):
        pass

    def update_chicken(self, chicken, chicks, iteration, debug):
        pass
    def arbitrage_btkn(self, chicken, chicks, iteration, debug):
        pass
    def buy_btkn(self, chicken, chicks, debug):
        pass
    def sell_btkn(self, chicken, chicks, debug):
        pass
    def get_btkn_amm_slippage(self, chicken):
        pass

class TesterSimple(TesterInterface):
    def __init__(self):
        super().__init__()
        self.name = "Simple toll model"
        self.plot_prefix = '0_0'
        self.plot_file_description = 'simple_toll'

        self.price_max_value = 5
        self.apr_min_value = -10
        self.apr_max_value = 100
        self.time_max_value = 1000

        self.initial_price = INITIAL_BTKN_PRICE
        self.twap_period = TWAP_PERIOD
        self.price_premium = PRICE_PREMIUM
        self.price_volatility = PRICE_VOLATILITY

        self.external_yield = EXTERNAL_YIELD

        self.accrual_param = INITIAL_ACCRUAL_PARAM
        self.chicken_in_gamma_shape = CHICKEN_IN_GAMMA[0]
        self.chicken_in_gamma_scale = CHICKEN_IN_GAMMA[1]
        self.chicken_out_probability = CHICKEN_OUT_PROBABILITY
        self.chicken_in_amm_fee = CHICKEN_IN_AMM_FEE

        self.rebonders = NUM_REBONDERS
        self.lps = NUM_LPS
        self.sellers = NUM_SELLERS
        self.traders = NUM_TRADERS

        self.max_slippage = MAX_SLIPPAGE
        self.amm_yield = AMM_YIELD

        return

    def init(self, chicks):
        for i in range(self.rebonders):
            chicks[i].rebonder = True
        start = self.rebonders
        end = start + self.lps
        for i in range(start, end):
            chicks[i].lp = True
        start = end
        end = start + self.sellers
        for i in range(start, end):
            chicks[i].seller = True
        start = end
        end = start + self.traders
        for i in range(start, end):
            chicks[i].trader = True

        return

    def prefixes_getter(self):
        return self.plot_prefix, self.plot_file_description

    # TODO: index them
    def get_bonded_chicks(self, chicks):
        return list(filter(lambda chick: chick.bond_amount > 0, chicks))

    def get_bonded_chicks_lps(self, chicks):
        return list(filter(lambda chick: chick.bond_amount > 0 and chick.lp, chicks))

    def get_bonded_chicks_non_lps(self, chicks):
        return list(filter(lambda chick: chick.bond_amount > 0 and not chick.lp, chicks))

    def get_bonded_chicks_rebonders(self, chicks):
        return list(filter(lambda chick: chick.bond_amount > 0 and chick.rebonder, chicks))

    def get_bonded_chicks_others(self, chicks):
        return list(filter(lambda chick: chick.bond_amount > 0 and not chick.rebonder and not chick.lp, chicks))

    def get_not_bonded_chicks(self, chicks):
        return list(filter(lambda chick: chick.bond_amount == 0, chicks))

    def get_available_for_bonding_chicks(self, chicken, chicks):
        return list(
            filter(lambda chick: chick.bond_amount == 0 and chicken.token.balance_of(chick.account) > 0 and not chick.trader, chicks))

    def get_token_hodlers(self, chicken, chicks, threshold=0):
        return list(filter(lambda chick: chicken.token.balance_of(chick.account) > threshold, chicks))

    def get_btkn_hodlers(self, chicken, chicks, threshold=0):
        return list(filter(lambda chick: chicken.btkn.balance_of(chick.account) > threshold, chicks))

    def get_lp_hodlers(self, chicken, chicks, threshold=0):
        return list(filter(lambda chick: chicken.btkn_amm.lp_token.balance_of(chick.account) > threshold, chicks))

    def get_traders_with_token(self, chicken, chicks, threshold=0):
        return list(filter(lambda chick: chick.trader and chicken.token.balance_of(chick.account) > threshold, chicks))

    def get_traders_with_btkn(self, chicken, chicks, threshold=0):
        return list(filter(lambda chick: chick.trader and chicken.btkn.balance_of(chick.account) > threshold, chicks))

    #def is_pre_chicken_in_phase(self, chicken, chicks):
        #return len(self.get_btkn_hodlers(chicken, chicks)) == 0
    def is_before_first_chicken_in(self, chicken):
        return chicken.btkn.total_supply == 0

    def get_bond_cap(self, bond_amount, backing_ratio):
        if backing_ratio == 0:
            return 999999999
        return bond_amount / backing_ratio

    def get_natural_rate(self, previous_natural_rate, iteration):
        np.random.seed(2021 * iteration)
        shock_natural_rate = np.random.normal(0, SD_NATURAL_RATE)
        new_natural_rate = previous_natural_rate * (1 + shock_natural_rate)
        # print(f"previous natural rate: {previous_natural_rate:.3%}")
        # print(f"new natural rate:      {new_natural_rate:.3%}")

        return new_natural_rate

    def get_premium_by_yield_comparison(self, chicken):
        expected_bonding_time = 2 * TARGET_AVERAGE_AGE
        reserve_bucket = chicken.reserve_token_balance()
        pending_bucket = chicken.pending_token_balance()
        permanent_bucket = chicken.amm.get_value_in_token_A()

        reserve_yield = self.get_yield_amount(reserve_bucket, self.external_yield, expected_bonding_time)
        pending_yield = self.get_yield_amount(pending_bucket, self.external_yield, expected_bonding_time)
        amm_yield = self.get_yield_amount(permanent_bucket, self.amm_yield, expected_bonding_time)

        if reserve_bucket > 0:
            holding_roi = (reserve_yield + pending_yield + amm_yield) / reserve_bucket
        else:
            holding_roi = 0

        redemption_price = self.get_backing_ratio(chicken)
        fair_price = redemption_price * ((1 + holding_roi) ** 2)
        premium = fair_price - redemption_price

        return premium

    def get_premium(self, chicken):
        btkn_supply = chicken.btkn.total_supply
        if btkn_supply == 0:
            return 0

        base_amount = chicken.reserve_token_balance()

        mu = base_amount * PREMIUM_MU
        sigma = mu * PREMIUM_SIGMA

        # Different methods to estimate the premium of bLQTY tokens.
        premium_mapper = {"normal_dist": np.random.normal(mu, sigma, 1)[0] / btkn_supply,
                          # TODO: add reserve here too:
                          "perpetuity": (chicken.pending_token_balance() * EXTERNAL_YIELD) ** (1 / TIME_UNITS_PER_YEAR),
                          "pending_balance": chicken.pending_token_balance() / btkn_supply,
                          "full_balance": (chicken.pending_token_balance() + (self.amm_yield/self.external_yield) * chicken.amm.get_value_in_token_A()) / btkn_supply,
                          "yield_comparison": self.get_premium_by_yield_comparison(chicken),
                          }

        return premium_mapper.get(self.price_premium, 0)

    def get_fair_price(self, chicken):
        """
        Calculate the fair spot price of bLQTY. The price is determined by the price floor plus a premium.
        @param chicken: The reserves.
        @return: The bLQTY spot price.
        """

        btkn_supply = chicken.btkn.total_supply
        if btkn_supply == 0:
            return self.initial_price

        base_amount = chicken.reserve_token_balance()
        price_floor = base_amount / btkn_supply

        # Different methods to include volatility in the price.
        volatility_mapper = {"None": 0,
                             "bounded": min(np.random.normal(VOLA_MU, VOLA_SIGMA, 1), price_floor),
                             "unbounded": np.random.normal(VOLA_MU, VOLA_SIGMA, 1),
                             }

        total_price = price_floor \
                      + self.get_premium(chicken) \
                      + volatility_mapper.get(self.price_volatility, 0)

        return total_price

    def get_btkn_spot_price(self, chicken):
        return chicken.btkn_amm.get_token_B_price()

    def get_btkn_twap(self, data, iteration):
        if iteration <= self.twap_period:
            return self.initial_price
        # print(data[iteration - self.twap_period : iteration]["btkn_price"])
        # print(f"average: {data[iteration - self.twap_period : iteration].mean()['btkn_price']:,.2f}")
        return data[iteration - self.twap_period: iteration].mean()["btkn_price"]

    def get_btkn_price(self, chicken, data, iteration):
        return self.get_btkn_twap(data, iteration)

    def get_backing_ratio(self, chicken):
        return chicken.get_backing_ratio()

    def get_optimal_apr_chicken_in_time(self, chicken):
        # market/fair price
        m = self.get_btkn_spot_price(chicken)
        # backing ratio
        r = self.get_backing_ratio(chicken)
        # accrual param
        u = self.accrual_param
        # market/fair price with chicken in fee applied
        t = (1 - self.chicken_in_amm_fee) * m

        """
        print(f"fair price:    {m:,.2f}")
        print(f"backing ratio: {r:,.2f}")
        print(f"accrual param: {u:,.2f}")
        print(f"reduced p_f:   {t:,.2f}")
        """

        if t == 0:
            return TARGET_AVERAGE_AGE
        if t <= r:
            return ITERATIONS

        chicken_in_time = u * (r + math.sqrt(t * r)) / (t - r)

        assert chicken_in_time > 0

        return min(ITERATIONS, chicken_in_time)

    def get_twap_metric(self, chicken, data, iteration, variable):
        if iteration == 0:
            return 0
        if iteration <= self.twap_period:
            return data[0: iteration].mean()[variable]
        # print(data[iteration - self.twap_period : iteration][variable])
        # print(f"average: {data[iteration - self.twap_period : iteration].mean()[variable]:,.2f}")
        return data[iteration - self.twap_period: iteration].mean()[variable]

    def get_bonding_apr_spot(self, chicken):
        m = self.get_btkn_spot_price(chicken)
        r = self.get_backing_ratio(chicken)
        u = self.accrual_param
        if m <= r:
            return 0
        # optimal_time
        t = self.get_optimal_apr_chicken_in_time(chicken)
        apr = ((1 - self.chicken_in_amm_fee) * m/r * t / (t+u) - 1) * TIME_UNITS_PER_YEAR / t
        """
        print(f"backing ratio: {r:,.2f}")
        print(f"spot price:    {m:,.2f}")
        print(f"premium:       {p:,.2f}")
        print(f"optimal time:  {t:,.2f}")
        print(f"APR: {apr:,.2f}")
        """
        return apr

    def get_bonding_apr_twap(self, chicken, data, iteration):
        return self.get_twap_metric(chicken, data, iteration, "bonding_apr")

    def get_btkn_apr_spot(self, chicken, data, iteration):
        APR_SPAN = 30
        if iteration == 0:
            return 0

        span = min(APR_SPAN, iteration)
        previous_spot_price = data["btkn_price"][iteration-span]
        if previous_spot_price == 0:
            return 0
        current_spot_price = self.get_btkn_spot_price(chicken)
        #print(f"previous_spot_price: {previous_spot_price:,.2f}")
        #print(f"current_spot_price:  {current_spot_price:,.2f}")

        return (current_spot_price / previous_spot_price - 1) * TIME_UNITS_PER_YEAR / span

    def get_btkn_apr_twap(self, chicken, data, iteration):
        return self.get_twap_metric(chicken, data, iteration, "btkn_apr")

    def get_btkn_apr(self, chicken, data, iteration):
        return self.get_btkn_apr_twap(chicken, data, iteration)

    # https://www.desmos.com/calculator/taphbjrugg
    # See also: https://homepage.divms.uiowa.edu/~mbognar/applets/gamma.html
    def get_chicken_in_profit_percentage(self):
        return np.random.gamma(self.chicken_in_gamma_shape, self.chicken_in_gamma_scale, 1)[0]

    def get_yield_amount(self, base_amount, yield_percentage, time_units=1):
        return base_amount * ((1 + yield_percentage) ** (time_units / TIME_UNITS_PER_YEAR) - 1)

    # Special case before the first chicken in (actually, when bTKN supply is zero)
    # to avoid giving advantage to the first one
    def distribute_yield_pre_chicken_in(self, chicken, chicks, iteration):
        # Pending generated yield
        generated_yield = self.get_yield_amount(chicken.pending_token_balance(), self.external_yield)
        if generated_yield == 0:
            return

        """
        # previous mechanism, yield would go to AMM directly
        chicken.token.mint(chicken.reserve_account, generated_yield)
        chicken.btkn.mint(chicken.reserve_account, generated_yield/2)

        #print(f"Yield to AMM: {generated_yield/2:,.2f}")
        chicken.btkn_amm.add_liquidity(chicken.reserve_account, generated_yield/2, generated_yield/2)
        """

        # Use yield as rewards
        #print(f"Pre first chicken in yield: {generated_yield:,.2f}")
        if hasattr(chicken.btkn_amm, "rewards"):
            chicken.token.mint(chicken.btkn_amm.rewards.account, generated_yield)

        return

    def distribute_yield(self, chicken, chicks, iteration):
        if self.is_before_first_chicken_in(chicken):
            return self.distribute_yield_pre_chicken_in(chicken, chicks, iteration)
        # Reserve generated yield
        generated_yield = self.get_yield_amount(chicken.reserve_token_balance(), self.external_yield)

        chicken.token.mint(chicken.reserve_account, generated_yield)

        # AMM generated yield
        # TODO: use real fees!
        generated_yield = self.get_yield_amount(chicken.amm.get_value_in_token_A(), self.amm_yield)

        #print(f"generated_yield:      {generated_yield:,.2f}")
        chicken.token.mint(chicken.reserve_account, generated_yield)
        # Distribute rewards
        distributed_amount = chicken.btkn_amm.rewards.distribute_yield(1)
        #print(f"distributed_amount: {distributed_amount:,.2f}")
        for chick in self.get_lp_hodlers(chicken, chicks):
            reward_chick_amount = distributed_amount * chicken.btkn_amm.get_lp_share(chick.account)
            #print(f"LP share:  {chicken.btkn_amm.get_lp_share(chick.account):.6%}")
            #print(f"Bal before: {chicken.token.balance_of(chick.account):,.6f}")
            #print(f"Chick reward: {reward_chick_amount:,.2f}")
            chicken.token.transfer(chicken.btkn_amm.rewards.account, chick.account, reward_chick_amount)
            #print(f"Bal after: {chicken.token.balance_of(chick.account):,.6f}")

        return

    def get_bond_probability(self, chicken):
        # TODO: move constants to constants.py?
        # chicken_in_time
        t = self.get_optimal_apr_chicken_in_time(chicken)
        #p = max(0, min(1, 0.1 * (290 - 9*t) / 200))
        p = min(1, 0.1 * 100 / t**2)
        return p

    def bond(self, chicken, chicks, iteration):
        np.random.seed(2022 * iteration)
        np.random.shuffle(chicks)
        not_bonded_chicks = self.get_available_for_bonding_chicks(chicken, chicks)
        if iteration == 0:
            num_new_bonds = BOOTSTRAP_NUM_BONDS
        else:
            not_bonded_chicks_len = len(not_bonded_chicks)
            num_new_bonds = np.random.binomial(not_bonded_chicks_len, self.get_bond_probability(chicken))
            #print(f"available: {not_bonded_chicks_len:,.2f}")
        #print(f"bonding:   {num_new_bonds:,.2f}")
        for chick in not_bonded_chicks[:num_new_bonds]:
            chick_balance = chicken.token.balance_of(chick.account)
            if chick_balance < BOND_AMOUNT[0]:
                continue
            amount = min(
                np.random.randint(BOND_AMOUNT[0], BOND_AMOUNT[1], 1)[0],
                chick_balance
            )
            target_profit = self.get_chicken_in_profit_percentage()
            """
            print("\n \033[33m--> Bonding!\033[0m")
            print(chick)
            print(f"amount: {amount:,.2f}")
            print(f"chick_balance: {chick_balance:,.2f}")
            print(f"profit: {target_profit:.3%}")
            """
            chicken.bond(chick, amount, target_profit, iteration)
        return

    def get_avg_outstanding_bond_age(self, chicks, iteration):
        bonded_chicks = self.get_bonded_chicks(chicks)

        if not bonded_chicks:
            return 0

        # size-weighted average
        numerator = sum(map(lambda chick: chick.bond_amount * (iteration - chick.bond_time), bonded_chicks))
        denominator = sum(map(lambda chick: chick.bond_amount, bonded_chicks))

        return numerator / denominator

    def update_chicken(self, chicken, chicks, data, iteration, debug=False):
        """ Update the state of each user. Users may:
            - chicken-out
            - chicken-in
        with predefined probabilities.

        @param chicken: The resources
        @param chicks: All users
        @param data: Logging data
        @param iteration: The iteration step
        """

        np.random.seed(2023 * iteration)
        np.random.shuffle(chicks)

        # ----------- Chicken-out --------------------
        bonded_chicks = self.get_bonded_chicks(chicks)
        if debug:
            print(f"Bonded Chicks ini: {len(bonded_chicks)}")

        for chick in bonded_chicks:
            backing_ratio = self.get_backing_ratio(chicken)

            # Check if chicken-out conditions are met and eventually chicken-out
            self.chicken_out(chicken, chick, iteration, data)

        # ----------- Chicken-in --------------------
        if iteration < BOOTSTRAP_PERIOD_CHICKEN_IN:
            return

        # LPs first
        bonded_chicks = self.get_bonded_chicks_lps(chicks)
        if debug:
            print(f"Bonded Chicks before LPs: {len(bonded_chicks)}")

        for chick in bonded_chicks:
            # Check if chicken-in conditions are met and eventually chicken-in
            self.chicken_in(chicken, chick, iteration, data, debug)

        # Non LPs afterwards
        bonded_chicks = self.get_bonded_chicks_non_lps(chicks)
        if debug:
            print(f"Bonded Chicks before sellers: {len(bonded_chicks)}")

        for chick in bonded_chicks:
            # Check if chicken-in conditions are met and eventually chicken-in
            self.chicken_in(chicken, chick, iteration, data, debug)

        if debug:
            print(f"Bonded Chicks fin: {len(self.get_bonded_chicks(chicks))}")
            print(f"price: {chicken.btkn_amm.get_token_B_price():,.2f}")
            print("Out:", self.chicken_out_counter)
            print("In:", self.chicken_in_counter)

        return

    def is_bootstrap_chicken_out(self, chick, iteration):
        return iteration <= BOOTSTRAP_PERIOD_CHICKEN_IN and chick.bond_time == 0

    def set_accrual_param(self, new_value):
        self.accrual_param = new_value

    def get_claimable_btkn_amount(self, chicken, chick, iteration):
        backing_ratio = self.get_backing_ratio(chicken)
        bond_cap = self.get_bond_cap(chick.bond_amount, backing_ratio)
        bond_duration = iteration - chick.bond_time
        claimable_btkn_amount =  bond_cap * bond_duration / (bond_duration + self.accrual_param)
        """
        print("")
        print(f"backing_ratio:        {backing_ratio}")
        print(f"bond_cap:         {bond_cap}")
        print(f"bond_amount:      {chick.bond_amount}")
        print(f"bond_duration:    {bond_duration}")
        print(f"T factor:         {bond_duration / (bond_duration + 1)}")
        print(f"claimable_btkn_amount: {claimable_btkn_amount}")
        """
        assert claimable_btkn_amount < bond_cap or claimable_btkn_amount == 0
        return claimable_btkn_amount, bond_cap

    def chicken_out(self, chicken, chick, iteration, data):
        """ Chicken  out defines leaving users. User are only allowed to leave if
        the break-even point of the investment is not reached with a predefined
        probability.

        @param chicken: Resources
        @param chick: All users
        @param iteration:
        @param data:
        """

        # use actual btkn price instead of weighted average
        # btkn_price = self.get_btkn_price(chicken, data, iteration)
        btkn_price = self.get_btkn_spot_price(chicken)
        claimable_btkn_amount, _ = self.get_claimable_btkn_amount(chicken, chick, iteration)
        profit = claimable_btkn_amount * btkn_price - chick.bond_amount

        # skip chicken out for bootstrappers
        if self.is_bootstrap_chicken_out(chick, iteration):
            return

        # if break even is reached or chicken-out proba (10%) is not fulfilled
        if profit > 0 or np.random.binomial(1, self.chicken_out_probability) == 0:
            return

        #print("\n \033[33m--> Chickening out!\033[0m")
        #print(chick)

        chicken.chicken_out(chick)
        self.chicken_out_counter += 1

        return

    def is_bootstrap_chicken_in(self, chick, iteration):
        return iteration == BOOTSTRAP_PERIOD_CHICKEN_IN and chick.bond_time == 0

    def get_permanent_amm_amounts(self, chicken, bond_cap, claimable_btkn_amount):
        backing_ratio = self.get_backing_ratio(chicken)

        amm_btkn_amount = bond_cap - claimable_btkn_amount
        # Forget about LQTY/ETH price for now
        amm_token_amount = amm_btkn_amount * backing_ratio / 2 * (1 - self.chicken_in_amm_fee)
        amm_coll_amount = amm_token_amount

        """
        print("- Divert to AMM")
        print(f"token:      {amm_token_amount:,.2f}")
        print(f"2 x token:  {2*amm_token_amount:,.2f}")
        print(f"btkn:     {amm_btkn_amount:,.2f}")
        print("")
        """

        return amm_token_amount, amm_coll_amount

    def divert_to_permanent_amm(self, chicken, token_amount, coll_amount):
        # Simulate a swap LQTY -> ETH
        # “magically” mint ETH
        chicken.coll_token.mint(chicken.reserve_account, coll_amount+1)
        # “magically” burn LQTY
        chicken.token.burn(chicken.reserve_account, token_amount)

        # Add liquidity
        chicken.amm.add_liquidity(chicken.reserve_account, token_amount, coll_amount)

        return

    def get_rebond_time(self, chicken):
        from scipy.special import lambertw
        btkn_spot_price = self.get_btkn_spot_price(chicken)
        backing_ratio = self.get_backing_ratio(chicken)
        reduced_spot_price = (1 - self.chicken_in_amm_fee) * btkn_spot_price
        if btkn_spot_price == 0 or backing_ratio >= reduced_spot_price:
            #print(f"btkn price:     {btkn_spot_price}")
            #print(f"redemption price: {backing_ratio}")
            return ITERATIONS

        w = lambertw(math.exp(1) * backing_ratio / reduced_spot_price).real
        rebond_time = w / (1 - w)
        """
        print("")
        print(f"btkn price:                {btkn_spot_price}")
        print(f"redemption price:          {backing_ratio}")
        print(f"price with chicken in fee: {reduced_spot_price}")
        print(f"lambda:                    {btkn_spot_price/backing_ratio}")
        print(f"lambertW:                  {w}")
        print(f"rebond_time:               {rebond_time:,.2f}\033[0m")
        print(f"accrual param:             {self.accrual_param}")
        print(f"\033[34mFinal rebond time:          {self.accrual_param * rebond_time.real:,.2f}\033[0m")
        """

        return min(self.accrual_param * rebond_time.real, ITERATIONS)

    def rebond(self, chicken, chick, claimable_btkn_amount, iteration, debug=False):
        # If it’s a rebonder and the optimal point hasn’t been reached yet
        rebond_time = self.get_rebond_time(chicken)
        # If the optimal point hasn’t been reached yet, or liquidity is too thin
        if iteration - chick.bond_time < rebond_time \
           or claimable_btkn_amount > CHICKEN_IN_LIQUIDITY_FACTOR * chicken.btkn.balance_of(chicken.btkn_amm.pool_account):
            if debug:
                print(f"chicken_in_time: {chicken_in_time:,.2f}")
                print(f"time gone:       {iteration - chick.bond_time:,.2f}")
            return 0

        if debug:
            print("\n --> Chickening in! (Rebond)")
        claimable_btkn_amount = chicken.chicken_in(chick, claimable_btkn_amount, self.chicken_in_amm_fee)

        # sell bTKN in the AMM
        # we use all balance in case a previous rebond was capped due to low liquidity
        btkn_balance = chicken.btkn.balance_of(chick.account)
        assert btkn_balance >= claimable_btkn_amount
        max_swap_amount = chicken.btkn_amm.get_input_B_for_max_slippage(self.max_slippage, 0, 0)
        btkn_swap_amount = min(
            max_swap_amount,
            btkn_balance,
        )
        #print("Rebond -> sell bLQTY")
        bought_token_amount = chicken.btkn_amm.swap_B_for_A(chick.account, btkn_swap_amount)
        if bought_token_amount < BOND_AMOUNT[0]:
            #print(f"max swap:     {max_swap_amount:,.2f}")
            return 0
        # bond again
        chicken.bond(chick, bought_token_amount, 0, iteration)

        if debug:
            print("")
            print("-- Rebond")
            print(chick)
            print(f"max swap:     {max_swap_amount:,.2f}")
            print(f"claimable:    {claimable_btkn_amount:,.2f}")
            print(f"balance:      {btkn_balance:,.2f}")
            print(f"Sold bTKN:  {btkn_swap_amount:,.2f}")
            print(f"Bought TOKEN: {bought_token_amount:,.2f}")
            print("\n \033[32mBalances after\033[0m")
            print(f" - {chicken.token.symbol} balance: {chicken.token.balance_of(chick.account):,.2f}")
            print(f" - {chicken.token.symbol} bonded:  {chick.bond_amount:,.2f}")
            print(f" - {chicken.btkn.symbol} balance: {chicken.btkn.balance_of(chick.account):,.2f}")

        assert chick.bond_amount > BOND_AMOUNT[0]

        return 1

    def lp_chicken_in(self, chicken, chick, claimable_btkn_amount, iteration, debug=False):
        assert iteration >= BOOTSTRAP_PERIOD_CHICKEN_IN

        is_first_chicken_in = self.is_before_first_chicken_in(chicken)
        # If it’s an LP it will chicken in if:
        # it’s first one, or
        # btkn APR is high, or
        # the optimal point has been reached yet
        # Otherwise skip
        chicken_in_time = self.get_optimal_apr_chicken_in_time(chicken)
        if not is_first_chicken_in \
           and chicken.amm_iteration_apr < 0.1 \
           and iteration - chick.bond_time < chicken_in_time:
            if debug:
                print(f"is first chicken in?: {self.is_before_first_chicken_in(chicken)}")
                print(f"chicken_in_time: {chicken_in_time:,.2f}")
                print(f"time gone:       {iteration - chick.bond_time:,.2f}")
            return 0

        if debug:
            print(f"\n --> Chickening in! (LP), on {iteration}")
        claimable_btkn_amount = chicken.chicken_in(chick, claimable_btkn_amount, self.chicken_in_amm_fee)

        # Provide liquidity to TOKEN/bTKN pool
        #print("\n \033[32mAdd liquidity!\033[0m \n")
        # First one sets the price
        if is_first_chicken_in:
            token_liquidity_amount = claimable_btkn_amount * INITIAL_BTKN_PRICE
            assert chicken.token.balance_of(chick.account) >= token_liquidity_amount
        else:
            liquidity_amount = chicken.btkn_amm.get_A_amount_for_liquidity(claimable_btkn_amount)
            token_liquidity_amount = min(
                liquidity_amount * 0.9999, # to avoid rounding issues
                chicken.token.balance_of(chick.account)
            )

        #print(f"token amount added: {token_liquidity_amount:,.2f}")
        #print(f"btkn amount added:  {claimable_btkn_amount:,.2f}")
        if token_liquidity_amount > 0:
            chicken.btkn_amm.add_liquidity(chick.account, token_liquidity_amount, claimable_btkn_amount)
        if debug:
            print("")
            print("-- LP")
            print(chick)
            print(f"claimable:    {claimable_btkn_amount:,.2f}")
            print(f"liquidity:    {liquidity_amount:,.2f}")
            print(f"balance:      {chicken.token.balance_of(chick.account):,.2f}")
            print("\n \033[32mBalances after\033[0m")
            print(f" - {chicken.token.symbol} balance: {chicken.token.balance_of(chick.account):,.2f}")
            print(f" - {chicken.token.symbol} bonded:  {chick.bond_amount:,.2f}")
            print(f" - {chicken.btkn.symbol} balance: {chicken.btkn.balance_of(chick.account):,.2f}")
            print(f" - {chicken.btkn_amm.lp_token.symbol} balance: {chicken.btkn_amm.lp_token.balance_of(chick.account):,.2f}")
            print(chicken.btkn_amm)

        return 1

    def seller_chicken_in(self, chicken, chick, claimable_btkn_amount, iteration, debug):
        chicken_in_time = self.get_optimal_apr_chicken_in_time(chicken)
        # If the optimal point hasn’t been reached yet, or liquidity is too thin
        if iteration - chick.bond_time < chicken_in_time \
           or claimable_btkn_amount > CHICKEN_IN_LIQUIDITY_FACTOR * chicken.btkn.balance_of(chicken.btkn_amm.pool_account):
            if debug:
                print(f"chicken_in_time: {chicken_in_time:,.2f}")
                print(f"time gone:       {iteration - chick.bond_time:,.2f}")
            return 0

        obtained_btkn_amount = chicken.chicken_in(chick, claimable_btkn_amount, self.chicken_in_amm_fee)
        #print(f"obtained_btkn_amount: {obtained_btkn_amount:,.2f}")
        #print(f"claimable_btkn_amount: {claimable_btkn_amount:,.2f}")
        # TODO: assert obtained_btkn_amount == claimable_btkn_amount
        # Sell obtained bTKN
        btkn_swap_amount = min(
            chicken.btkn_amm.get_input_B_for_max_slippage(self.max_slippage, 0, 0),
            obtained_btkn_amount,
        )
        obtained_token_amount = chicken.btkn_amm.swap_B_for_A(chick.account, btkn_swap_amount)
        if debug:
            print("\n --> Chickening in! (seller)")
            print(f"Claimable: {claimable_btkn_amount:,.2f}")
            print(f"Swapping: {btkn_swap_amount:,.2f}")
            print(f"Got: {obtained_token_amount:,.2f}")

        return 1

    def chicken_in(self, chicken, chick, iteration, data, debug=False):
        """ User may chicken-in if the have already exceeded the break-even
        point of their investment and not yet exceeded the bonding cap.

        @param chicken: The resources.
        @param chick: The user
        @param iteration: The iteration step
        @param data: Logging data
        """

        if iteration < BOOTSTRAP_PERIOD_CHICKEN_IN:
            return

        claimable_btkn_amount, bond_cap = self.get_claimable_btkn_amount(chicken, chick, iteration)
        if claimable_btkn_amount == 0:
            return

        # make sure at least break even
        btkn_spot_price = self.get_btkn_spot_price(chicken)
        if btkn_spot_price > 0 and claimable_btkn_amount * btkn_spot_price <  chick.bond_amount:
            if debug:
                print(f"claimable_btkn_amount: {claimable_btkn_amount:,.2f}")
                print(f"btkn_spot_price: {btkn_spot_price:,.2f}")
                print(f"chick.bond_amount: {chick.bond_amount:,.2f}")

            return

        amm_token_amount, amm_coll_amount = self.get_permanent_amm_amounts(chicken, bond_cap, claimable_btkn_amount)

        if debug:
            print("")
            print(chick)
            print("-- Chicken in")
            print(f"claimable_btkn_amount: {claimable_btkn_amount:,.2f}")
            print(f"bond cap:         {bond_cap:,.2f}")
            print(f"bond amount:      {chick.bond_amount:,.2f}")
            print(f"bond time:        {chick.bond_time}")
            print(f"amm amount:       {amm_token_amount:,.2f}")
            print(f"reserve ratio:        {self.get_backing_ratio(chicken):,.2f}")
            print(f"new reserve amount:   {chick.bond_amount - 2*amm_token_amount:,.2f}")
            print(f"new ratio:        {(chick.bond_amount - 2*amm_token_amount) / claimable_btkn_amount:,.2f}")

        # if for some reason bond amount goes below lower limit, it’s better to do a regular chicken in and start over
        if chick.rebonder:
            # Rebond
            if debug:
                print("\n \033[33m--> Rebonding!\033[0m")
            new_chicken_in = self.rebond(chicken, chick, claimable_btkn_amount, iteration)
            if debug:
                print(chicken.btkn_amm)
        elif chick.lp:
            if debug:
                print("\n \033[33m--> LP!\033[0m")
            new_chicken_in = self.lp_chicken_in(chicken, chick, claimable_btkn_amount, iteration)
        elif chick.seller:
            if debug:
                print("\n \033[33m--> seller!\033[0m")
            new_chicken_in = self.seller_chicken_in(chicken, chick, claimable_btkn_amount, iteration, debug)
            if debug:
                print(chicken.btkn_amm)
        else:
            raise RuntimeError('Unknown chick type!!')

        self.chicken_in_counter += new_chicken_in

        # Redirect part of bond to Permanent
        if amm_token_amount > 0 and new_chicken_in > 0:
            if debug:
                print(f"\n --> Diverting {amm_token_amount:,.2f} / {amm_coll_amount:,.2f}")
            self.divert_to_permanent_amm(chicken, amm_token_amount, amm_coll_amount)

        return

    def arbitrage_btkn(self, chicken, chicks, iteration, debug=False):
        if iteration < BOOTSTRAP_PERIOD_REDEEM:
            return
        if debug:
            print(" -- arbitrage_btkn")

        # Buy -> Redeem
        for chick in self.get_traders_with_token(chicken, chicks):
            btkn_spot_price = self.get_btkn_spot_price(chicken)
            backing_ratio = self.get_backing_ratio(chicken)
            if btkn_spot_price >= 0.99 * backing_ratio: # to account for fees and avoid rounding issues
                return
            if debug:
                print("Buy -> Redeem")
                print(chicken.btkn_amm)
                print(f"btkn_spot_price:  {btkn_spot_price:,.6f}")
                print(f"backing_ratio:    {backing_ratio:,.6f}")
                print(f"input from target: {chicken.btkn_amm.get_input_A_amount_from_target_price_B(backing_ratio):,.6f}")
                print(f"chick bal: {chicken.token.balance_of(chick.account):,.6f}")
            # buy bTKN
            tkn_amount = min(
                chicken.btkn_amm.get_input_A_amount_from_target_price_B(backing_ratio),# debug),
                chicken.token.balance_of(chick.account)
            )
            if tkn_amount == 0:
                return
            btkn_amount = chicken.btkn_amm.swap_A_for_B(chick.account, tkn_amount)
            if debug:
                print(" -- arbitrage_btkn (cont.)")
                print(f"tkn_amount: {tkn_amount:,.6f}")
                print(f"btkn_amount: {btkn_amount:,.6f}")
                print(f"btkn price after swap: {self.get_btkn_spot_price(chicken):,.6f}")

            # redeem bTKN
            redemption_amount = chicken.redeem(chick, btkn_amount)

            if debug or redemption_amount < tkn_amount:
                print(f"redemption_amount: {redemption_amount:,.6f}")
                print(f"tkn_amount: {tkn_amount:,.6f}")
            assert redemption_amount >= tkn_amount

        # Redeem -> Buy
        for chick in self.get_traders_with_btkn(chicken, chicks):
            btkn_spot_price = self.get_btkn_spot_price(chicken)
            backing_ratio = self.get_backing_ratio(chicken)
            if btkn_spot_price >= 0.99 * backing_ratio: # to account for fees and avoid rounding issues
                return
            if debug:
                print("Redeem -> Buy")
                print(chicken.btkn_amm)
                print(f"btkn_spot_price:  {btkn_spot_price:,.6f}")
                print(f"backing_ratio:    {backing_ratio:,.6f}")
                print(f"input from target: {chicken.btkn_amm.get_input_A_amount_from_target_price_B(backing_ratio):,.6f}")
                print(f"chick bal: {chicken.token.balance_of(chick.account):,.6f}")

            # redeem bTKN
            buy_input_max_amount = chicken.btkn_amm.get_input_A_amount_from_target_price_B(backing_ratio, debug)
            btkn_amount = buy_input_max_amount / backing_ratio
            redemption_amount = chicken.redeem(chick, btkn_amount)
            if debug:
                print(" -- arbitrage_btkn (cont.)")
                print(f"buy_input_max_amount: {buy_input_max_amount:,.6f}")
                print(f"redemption_amount: {redemption_amount:,.6f}")
                print(f"btkn_amount: {btkn_amount:,.6f}")
            if buy_input_max_amount == 0:
                return
            assert abs(redemption_amount - buy_input_max_amount) < 0.01
            if redemption_amount == 0:
                return

            # buy bTKN
            new_btkn_amount = chicken.btkn_amm.swap_A_for_B(chick.account, redemption_amount)
            if debug:
                print(f"new_btkn_amount: {new_btkn_amount:,.6f}")
                print(f"btkn price after swap: {self.get_btkn_spot_price(chicken):,.6f}")

            assert new_btkn_amount >= btkn_amount

        return

    def buy_btkn(self, chicken, chicks, debug=False):
        if chicken.btkn.total_supply == 0:
            return
        if debug:
            print("")
            print(" -- buy_btkn")

        for chick in self.get_traders_with_token(chicken, chicks):
            btkn_spot_price = self.get_btkn_spot_price(chicken)
            btkn_fair_price = self.get_fair_price(chicken)
            btkn_redemption_price = self.get_backing_ratio(chicken)
            if debug:
                print(f"btkn_spot_price:        {btkn_spot_price:,.6f}")
                print(f"btkn_fair_price:        {btkn_fair_price:,.6f}")
                print(f"btkn_redemption_price:  {btkn_redemption_price:,.6f}")
            arbitrage_premium_percentage = np.random.normal(
                BUY_PREMIUM_PERCENTAGE_MEAN,
                BUY_PREMIUM_PERCENTAGE_SD
            )
            target_price = min(
                (1 - arbitrage_premium_percentage) * btkn_redemption_price \
                + arbitrage_premium_percentage * btkn_fair_price,
                BUY_PRICE_CAP
            )
            if btkn_spot_price >= target_price:
                return

            if debug:
                print("")
                print("********")
                print(f"target_price: {target_price:,.2f}")
                print("")
            tkn_amount = min(
                chicken.btkn_amm.get_input_A_amount_from_target_price_B(target_price, debug),
                chicken.token.balance_of(chick.account)
            )
            previous_btkn_balance = chicken.btkn.balance_of(chick.account)
            if debug:
                print(f"tkn_amount: {tkn_amount:,.2f}")
                print(f"chick_balance: {chicken.token.balance_of(chick.account):,.2f}")
                print(f"previous bTKN bal: {previous_btkn_balance:,.2f}")
                print(f"previous buy price: {chick.buy_price:,.2f}")
                print(chicken.btkn_amm)
            btkn_amount = chicken.btkn_amm.swap_A_for_B(chick.account, tkn_amount)
            # Save average buy price to measure profits on sell
            if btkn_amount > 0:
                chick.buy_price = (previous_btkn_balance * chick.buy_price + tkn_amount) / (previous_btkn_balance + btkn_amount)
            if debug:
                print(f"Obtained bTKN: {btkn_amount:,.2f}")
                print(f"new buy price: {chick.buy_price:,.2f}")
                print(chicken.btkn_amm)

        if debug:
            print(f"Final spot price after buy: {self.get_btkn_spot_price(chicken):,.6f}")

        return

    def sell_btkn(self, chicken, chicks, debug=False):
        PROFIT_THRESHOLD = 0.01 # Don’t sell if profit below 1%
        MIN_SLIPPAGE = 0.01     # Over profit there must be some room for slippage
        if chicken.btkn.total_supply == 0:
            return

        if debug:
            print("\n -- sell_btkn")

        for chick in self.get_traders_with_btkn(chicken, chicks):
            btkn_spot_price = self.get_btkn_spot_price(chicken)
            if btkn_spot_price < self.get_backing_ratio(chicken):
                break
            if debug:
                print(f"btkn_spot_price:        {btkn_spot_price:,.6f}")
            token_balance = chicken.token.balance_of(chick.account)
            btkn_balance = chicken.btkn.balance_of(chick.account)
            # Check if in gains
            #profit = (token_balance + btkn_balance * btkn_spot_price) / INITIAL_AMOUNT - 1
            profit = btkn_spot_price / chick.buy_price - 1
            if debug:
                print(f"Buy price: {chick.buy_price:,.2f}")
                print(f"profit: {profit:.3%}")
            if profit <= PROFIT_THRESHOLD + MIN_SLIPPAGE:
                continue
            slippage = min(self.max_slippage, profit - PROFIT_THRESHOLD)
            max_swap_amount = chicken.btkn_amm.get_input_B_for_max_slippage(slippage, 0, 0, debug)
            btkn_swap_amount = min(
                max_swap_amount,
                btkn_balance,
            )
            if debug:
                print(f"slippage: {slippage:.3%}")
                print(f"Max swap for slippage: {max_swap_amount:,.2f}")
                print(f"chick_balance: {btkn_balance:,.2f}")
                print(f"btkn_swap_amount: {btkn_swap_amount:,.2f}")
                print(chicken.btkn_amm)
            btkn_amount = chicken.btkn_amm.swap_B_for_A(chick.account, btkn_swap_amount)
            if debug:
                print(chicken.btkn_amm)
        return

    def get_btkn_amm_slippage(self, chicken, debug=False):
        btkn_amount = chicken.btkn_amm.token_B_balance() * FRACTION_TO_SWAP
        token_amount = chicken.btkn_amm.token_A_balance() * FRACTION_TO_SWAP

        sell_slippage = chicken.btkn_amm.get_slippage_from_input_B(btkn_amount, debug)
        try:
            buy_slippage = chicken.btkn_amm.get_slippage_from_input_A(token_amount, debug)
        except:
            print("Didn’t converge trying to get slippage")
            buy_slippage = 0.3

        return sell_slippage, buy_slippage
