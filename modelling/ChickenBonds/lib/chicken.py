from lib.amm.uniswap import *
from lib.amm.amm_mock_price import *

class Chicken():
    def __init__(self, coll_token, token, btkn, pending_account, reserve_account, amm_account, amm_fee, btkn_amm_account, btkn_amm_fee):
        self.coll_token = coll_token
        self.token = token
        self.btkn = btkn

        self.pending_account = pending_account
        self.reserve_account = reserve_account

        self.amm = UniswapPool(amm_account, token, coll_token, amm_fee)
        #self.amm = ConstantPricePool(amm_account, token, btkn, amm_fee)
        #self.amm = StableSwapPool(amm_account, token, btkn, amm_fee, amplification_factor)
        self.btkn_amm = AmmMockPrice(btkn_amm_account, token, btkn, btkn_amm_fee)

        self.amm_iteration_apr = 0.0
        self.amm_average_apr = 0.0

        #self.outstanding_debt = 0.0

        return

    def pending_token_balance(self):
        return self.token.balance_of(self.pending_account)

    def reserve_token_balance(self):
        return self.token.balance_of(self.reserve_account)

    def owned_token_balance(self):
        return self.pending_token_balance() + self.reserve_token_balance()

    def get_backing_ratio(self):
        if self.btkn.total_supply == 0:
            return 1
        return self.reserve_token_balance() / self.btkn.total_supply

    def bond(self, user, amount, target_profit, iteration):
        assert user.bond_amount == 0
        self.token.transfer(user.account, self.pending_account, amount)
        user.bond_amount = amount
        user.bond_time = iteration
        user.bond_target_profit = target_profit
        return

    def chicken_in(self, user, claimable_btkn_amount, chicken_in_amm_fee):
        # Compute chicken in fee and deduct it from bond
        chicken_in_fee_amount = user.bond_amount * chicken_in_amm_fee
        user.bond_amount = user.bond_amount - chicken_in_fee_amount

        # Transfer chicken in fee amount
        self.token.transfer(self.pending_account, self.btkn_amm.pool_account, chicken_in_fee_amount)
        # Account for extra AMM revenue
        self.btkn_amm.add_rewards(chicken_in_fee_amount, 0)

        # Reduce claimable amount proportionally
        claimable_btkn_amount = claimable_btkn_amount * (1 - chicken_in_amm_fee)

        self.btkn.mint(user.account, claimable_btkn_amount)
        self.token.transfer(self.pending_account, self.reserve_account, user.bond_amount)
        user.bond_amount = 0
        user.bond_time = 0
        user.bond_target_profit = 0

        return claimable_btkn_amount

    def chicken_out(self, user):
        assert self.token.balance_of(self.pending_account) - user.bond_amount > -0.0001
        amount = min(user.bond_amount, self.token.balance_of(self.pending_account)) # to avoid rounding issues
        self.token.transfer(self.pending_account, user.account, amount)
        user.bond_amount = 0
        user.bond_time = 0
        user.bond_target_profit = 0
        return

    """
    def user_total_assets_value(self, user):
        token_balance = self.token.balance_of(user.account)
        btkn_balance = self.btkn.balance_of(user.account)

        amm_token = self.amm.token_A_balance_of(user.account)
        amm_btkn = self.amm.token_B_balance_of(user.account)

        btkn_price = self.amm.get_token_B_price()

        total_token = token_balance + amm_token
        total_btkn = btkn_balance + amm_btkn
        return total_token + total_btkn * btkn_price
    """
