from lib.amm.uniswap import *

class Chicken():
    def __init__(self, coll_token, token, stoken, coop_account, pol_account, amm_account, amm_fee):
        self.coll_token = coll_token
        self.token = token
        self.stoken = stoken

        self.coop_account = coop_account
        self.pol_account = pol_account

        self.amm = UniswapPool(amm_account, token, stoken, amm_fee)
        #self.amm = ConstantPricePool(amm_account, token, stoken, amm_fee)
        #self.amm = StableSwapPool(amm_account, token, stoken, amm_fee, amplification_factor)

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
        self.token.transfer(self.coop_account, user.account, user.bond_amount)
        user.bond_amount = 0
        user.bond_time = 0
        user.bond_target_profit = 0
        return

    """
    # TODO: collateral
    def borrow(self, user, token_amount):
        stoken_amount = self.amm.get_input_amount(self.stoken, self.token, token_amount)
        self.stoken.mint(user.account, stoken_amount)
        #fees_before = self.amm.get_accrued_fees_in_token_A()
        token_received = self.amm.swap_B_for_A(user.account, stoken_amount)
        #print(f"\033[32m[Borrowing]\033[0m Swapped {stoken_amount:.2f} sTOKEN for {token_received:.2f} TOKEN")
        #fees_after = self.amm.get_accrued_fees_in_token_A()
        #print(f"Fees generated: {fees_after - fees_before:,.2f}")
        self.outstanding_debt = self.outstanding_debt + token_received
        return stoken_amount, token_received

    # TODO: collateral
    def repay_debt(self, user, amount):
        if amount == 0 or amount > self.outstanding_debt:
            amount = self.outstanding_debt
        self.token.transfer(user.account, self._account, amount)
        self.outstanding_debt = self.outstanding_debt - amount
        return

    def user_total_assets_value(self, user):
        token_balance = self.token.balance_of(user.account)
        stoken_balance = self.stoken.balance_of(user.account)

        amm_token = self.amm.token_A_balance_of(user.account)
        amm_stoken = self.amm.token_B_balance_of(user.account)

        stoken_price = self.amm.get_token_B_price()

        total_token = token_balance + amm_token
        total_stoken = stoken_balance + amm_stoken
        return total_token + total_stoken * stoken_price
    """
