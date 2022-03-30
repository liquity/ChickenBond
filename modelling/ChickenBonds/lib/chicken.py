from lib.amm.uniswap import *
from lib.amm.amm_mock_price import *

class Chicken():
    def __init__(self, coll_token, token, stoken, coop_account, pol_account, amm_account, amm_fee, stoken_amm_account, stoken_amm_fee):
        self.coll_token = coll_token
        self.token = token
        self.stoken = stoken

        self.coop_account = coop_account
        self.pol_account = pol_account

        self.amm = UniswapPool(amm_account, token, coll_token, amm_fee)
        #self.amm = ConstantPricePool(amm_account, token, stoken, amm_fee)
        #self.amm = StableSwapPool(amm_account, token, stoken, amm_fee, amplification_factor)
        self.stoken_amm = AmmMockPrice(stoken_amm_account, token, stoken, stoken_amm_fee)

        self.amm_iteration_apr = 0.0
        self.amm_average_apr = 0.0

        #self.outstanding_debt = 0.0

        return

    def coop_token_balance(self):
        return self.token.balance_of(self.coop_account)

    def pol_token_balance(self):
        return self.token.balance_of(self.pol_account)

    def reserve_token_balance(self):
        return self.coop_token_balance() + self.pol_token_balance()

    def permanent_bucket_value(self):
        return self.amm.get_value_in_token_A_of(self.pol_account)

    def get_pol_ratio_no_amm(self):
        if self.stoken.total_supply == 0:
            return 1
        return self.pol_token_balance() / self.stoken.total_supply

    def get_pol_ratio_with_amm(self):
        if self.stoken.total_supply == 0:
            return 1

        amm_value = self.permanent_bucket_value()
        return (self.pol_token_balance() + amm_value) / self.stoken.total_supply

    def bond(self, user, amount, target_profit, iteration):
        assert user.bond_amount == 0
        self.token.transfer(user.account, self.coop_account, amount)
        user.bond_amount = amount
        user.bond_time = iteration
        user.bond_target_profit = target_profit
        return

    def top_up_bond(self, user, amount):
        assert user.bond_amount > 0
        self.token.transfer(user.account, self.coop_account, amount)
        user.bond_amount = user.bond_amount + amount
        return

    def chicken_in(self, user, stoken_amount):
        self.stoken.mint(user.account, stoken_amount)
        self.token.transfer(self.coop_account, self.pol_account, user.bond_amount)
        user.bond_amount = 0
        user.bond_time = 0
        user.bond_target_profit = 0
        return

    def chicken_out(self, user):
        assert self.token.balance_of(self.coop_account) - user.bond_amount > -0.0001
        amount = min(user.bond_amount, self.token.balance_of(self.coop_account)) # to avoid rounding issues
        self.token.transfer(self.coop_account, user.account, amount)
        user.bond_amount = 0
        user.bond_time = 0
        user.bond_target_profit = 0
        return

