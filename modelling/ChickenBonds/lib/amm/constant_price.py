from lib.amm.amm_base import *

class ConstantPricePool(AmmBase):

    def get_A_amount_for_liquidity(self, token_B_amount):
        return token_B_amount
    def get_B_amount_for_liquidity(self, token_A_amount):
        return token_A_amount
    def add_liquidity(self, account, token_A_amount, max_token_B_amount):
        assert max_token_B_amount >= token_A_amount

        total_liquidity = self.get_total_liquidity()
        if total_liquidity == 0: # initial liquidity
            assert token_A_amount > 1.0

            self.token_A.transfer(account, self.pool_account, token_A_amount)
            self.token_B.transfer(account, self.pool_account, token_A_amount)

            self.lp_token.mint(account, token_A_amount)
        else:
            token_A_reserve = self.token_A_balance()
            liquidity_minted = token_A_amount * total_liquidity / token_A_reserve

            self.token_A.transfer(account, self.pool_account, token_A_amount)
            self.token_B.transfer(account, self.pool_account, token_A_amount)

            self.lp_token.mint(account, liquidity_minted)
        return

    def add_liquidity_single_A(self, account, token_A_amount, max_slippage):
        token_A_reserve = self.token_A_balance()
        amount_to_add = token_A_amount / 2
        amount_to_swap = token_A_amount - amount_to_add
        token_B_amount = self.swap_A_for_B(account, amount_to_swap)
        return self.add_liquidity(account, amount_to_add, token_B_amount)

    def get_output_amount(self, input_token_balance, output_token_balance, input_amount, D_offset=None):
        return input_amount * (1 - self.fee) - 0.000001 # to avoid rounding issues

    def get_input_amount(self, input_token, output_token, output_amount):
        return output_amount / (1 - self.fee)

    def get_token_A_price(self):
        return 1.0

    def get_token_B_price(self):
        return 1.0

    # Given a target token A price, returns the amount of token B that needs to be swapped to increase
    # current token A price to the desired target
    def get_input_B_amount_from_target_price_A(self, target_price):
        return 0

    # Given a target token B price, returns the amount of token A that needs to be swapped to increase
    # current token B price to the desired target
    def get_input_A_amount_from_target_price_B(self, target_price):
        return 0

    def get_input_A_for_max_slippage(self, slippage, token_A_offset, token_B_offset):
        input_amount = self.token_B_balance() + token_B_offset
        return input_amount / (1 - self.fee)

    def get_input_B_for_max_slippage(self, slippage, token_A_offset, token_B_offset):
        input_amount = self.token_A_balance() + token_A_offset
        return input_amount / (1 - self.fee)

    def get_output_A_for_max_slippage(self, slippage, token_A_offset, token_B_offset):
        return self.token_A_balance() + token_A_offset

    def get_output_B_for_max_slippage(self, slippage, token_A_offset, token_B_offset):
        return self.token_B_balance() + token_B_offset

