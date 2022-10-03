from lib.erc_token import *
from lib.amm.rewards import *

class AmmBase():
    def __init__(self, pool_account, token_A, token_B, fee, rewards_account=None, rewards_period=None):
        self.pool_account = pool_account # mimics the address
        if rewards_account:
            self.rewards = Rewards(token_A, rewards_account, rewards_period)
        self.token_A = token_A
        self.token_B = token_B
        self.lp_token = Token(token_A.symbol + token_B.symbol)
        assert fee > 0.0 and fee < 1.0
        self.fee = fee
        self.fees_accrued_A = 0.0
        self.fees_accrued_B = 0.0
        self.fees_accrued_LP = 0.0
        self.block_timestamp = 0 # for AMM time weighted oracle

    def __str__(self):
        return f"\n - {self.token_A.symbol} amount: {self.token_A.balance_of(self.pool_account):,.2f}" + \
            f"\n - {self.token_B.symbol} amount: {self.token_B.balance_of(self.pool_account):,.2f}" + \
            f"\n - Price {self.token_A.symbol}/{self.token_B.symbol}: {self.get_token_A_price():,.2f}" + \
            f"\n - \033[36mPrice {self.token_B.symbol}/{self.token_A.symbol}: {self.get_token_B_price():,.2f}\033[0m" + \
            f"\n - LP tokens total supply {self.get_total_liquidity():,.2f}"

    def convert_to_A(self, amount_A, amount_B):
        return amount_A + amount_B * self.get_token_B_price()
    def convert_to_B(self, amount_A, amount_B):
        return amount_A * self.get_token_A_price() + amount_B

    def token_A_balance(self):
        return self.token_A.balance_of(self.pool_account)
    def token_B_balance(self):
        return self.token_B.balance_of(self.pool_account)
    def get_value_in_token_A(self):
        A_balance = self.token_A_balance()
        B_balance = self.token_B_balance()
        return self.convert_to_A(A_balance, B_balance)
    def get_value_in_token_B(self):
        A_balance = self.token_A_balance()
        B_balance = self.token_B_balance()
        return self.convert_to_B(A_balance, B_balance)

    def get_total_liquidity(self):
        return self.lp_token.total_supply
    def get_liquidity(self, account):
        return self.lp_token.balance_of(account)
    def get_lp_share(self, account):
        if self.get_total_liquidity() == 0:
            return 0
        return self.get_liquidity(account) / self.get_total_liquidity()
    def token_A_balance_of(self, account):
        return self.token_A_balance() * self.get_lp_share(account)
    def token_B_balance_of(self, account):
        return self.token_B_balance() * self.get_lp_share(account)
    def get_value_in_token_A_of(self, account):
        A_balance = self.token_A_balance_of(account)
        B_balance = self.token_B_balance_of(account)
        return self.convert_to_A(A_balance, B_balance)
    def get_value_in_token_B_of(self, account):
        A_balance = self.token_A_balance_of(account)
        B_balance = self.token_B_balance_of(account)
        return self.convert_to_B(A_balance, B_balance)
    def get_lp_value_in_token_A(self, lp_amount):
        if self.get_total_liquidity() == 0:
            return 0
        A_value = self.get_value_in_token_A()
        return A_value * lp_amount / self.get_total_liquidity()

    def token_A_to_liquidity(self, amount):
        return amount * self.get_total_liquidity() / self.token_A_balance()
    def token_B_to_liquidity(self, amount):
        return amount * self.get_total_liquidity() / self.token_B_balance()

    def get_A_amount_for_liquidity(self, token_B_amount):
        pass
    def get_B_amount_for_liquidity(self, token_A_amount):
        pass
    def add_liquidity(self, account, token_A_amount, max_token_B_amount):
        pass

    def udpate_after_liquidity_movement(self):
        pass

    def add_liquidity_single_A(self, account, token_A_amount, max_slippage):
        pass

    def remove_liquidity(self, account, liquidity):
        total_liquidity = self.get_total_liquidity()
        # Don’t allow to withdraw more than owned
        account_liquidity = self.get_liquidity(account)
        print(f"owned liquidity:      {account_liquidity:,.2f}")
        print(f" liquidity to remove: {liquidity:,.2f}")
        liquidity = min(account_liquidity, liquidity)

        token_A_reserve = self.token_A_balance()
        token_B_reserve = self.token_B_balance()
        # prevent from draining pool to avoid rounding and zero division errors
        #if token_A_reserve < 1000 or token_B_reserve < 100:
        #    return 0, 0

        token_A_amount = liquidity * token_A_reserve / total_liquidity
        token_B_amount = liquidity * token_B_reserve / total_liquidity
        #print(f"Withdrawing {token_A_amount:,.2f} {self.token_A.symbol}")
        #print(f"Withdrawing {token_B_amount:,.2f} {self.token_B.symbol}")
        self.token_A.transfer(self.pool_account, account, token_A_amount)
        self.token_B.transfer(self.pool_account, account, token_B_amount)

        self.lp_token.burn(account, liquidity)

        return token_A_amount, token_B_amount

    def remove_all_liquidity(self, account):
        liquidity = self.get_liquidity(account)
        return self.remove_liquidity(account, liquidity)

    def remove_liquidity_single_A(self, account, token_A_amount, max_slippage):
        if token_A_amount < 10:
            return 0
        total_liquidity = self.get_total_liquidity()
        liquidity = self.get_liquidity(account)
        token_A_balance = self.token_A_balance_of(account)
        token_B_balance = self.token_B_balance_of(account)
        amount_B_max_slippage = self.get_input_B_for_max_slippage(max_slippage, -token_A_balance, -token_B_balance)
        if amount_B_max_slippage < token_B_balance:
            token_B_balance_swapped_to_A = self.get_output_amount(self.token_B_balance(), self.token_A_balance(), amount_B_max_slippage)
            liquidity_to_withdraw = liquidity * amount_B_max_slippage / token_B_balance
        else:
            token_B_balance_swapped_to_A = self.get_output_amount(self.token_B_balance(), self.token_A_balance(), token_B_balance)
            potential_A_balance = token_A_balance + token_B_balance_swapped_to_A
            liquidity_to_withdraw = liquidity * token_A_amount / potential_A_balance
            #print(f"pot: {potential_A_balance :,.2f}")
            if potential_A_balance == 0:
                return 0
        """
        print(" -- remove_liquidity_single_A")
        print(f"{self.token_A.symbol}: {token_A_balance :,.2f}")
        print(f"{self.token_B.symbol}: {token_B_balance :,.2f}")
        print(f"max slippage: {max_slippage:.3%}")
        print(f"amount B max slippage: {amount_B_max_slippage:,.2f}")
        print(f"{self.token_B.symbol} to swap: {token_B_balance_swapped_to_A:,.2f}")
        print(f"LP balance:     {liquidity:,.2f}")
        print(f"LP to withdraw: {liquidity_to_withdraw:,.2f}")
        """
        token_A_withdrawn, token_B_withdrawn = self.remove_liquidity(account, liquidity_to_withdraw)
        if token_A_withdrawn == 0 and token_B_withdrawn == 0:
            return 0
        swap_amount = self.swap_B_for_A(account, token_B_withdrawn)
        #print(f"\033[36m[Remove liquidity]\033[0m Swapped {token_B_withdrawn:.2f} {self.token_B.symbol} tokens for {swap_amount:.2f} {self.token_A.symbol} tokens")

        total_withdrawn = token_A_withdrawn + swap_amount
        withdraw_relative_error= abs(total_withdrawn - token_A_amount) / token_A_amount
        """
        print(f"ini: {token_A_amount :,.2f}")
        print(f"{self.token_A.symbol} withdrawn: {token_A_withdrawn :,.2f}")
        print(f"{self.token_A.symbol} from swap: {swap_amount :,.2f}")
        print(f"fin: {total_withdrawn :,.2f}")
        print(f"LP balance:     {liquidity:,.2f}")
        print(f"LP to withdraw: {liquidity_to_withdraw:,.2f}")
        print(f"LP supply: {total_liquidity:,.2f}")
        print(f"withdraw error: {withdraw_relative_error:,.2f}")
        print(f"Liquidity proportion: {liquidity_to_withdraw / total_liquidity:,.2f}")
        """
        # TODO:
        #assert withdraw_relative_error < 0.1 or withdraw_relative_error < liquidity_to_withdraw / total_liquidity * 1.1

        return total_withdrawn

    def remove_all_liquidity_single_A(self, account):
        token_A_withdrawn, token_B_withdrawn = self.remove_all_liquidity(account)
        swap_amount = self.swap_B_for_A(account, token_B_withdrawn)

        return token_A_withdrawn + swap_amount

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
        output_amount = self.get_output_amount(self.token_A_balance(), self.token_B_balance(), input_amount)
        #print(f"in:  {input_amount:,.2f}")
        #print(f"out: {output_amount:,.2f}")
        self.token_A.transfer(account, self.pool_account, input_amount)
        self.token_B.transfer(self.pool_account, account, output_amount)

        self.fees_accrued_A = self.fees_accrued_A + input_amount * self.fee

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
        output_amount = self.get_output_amount(self.token_B_balance(), self.token_A_balance(), input_amount)
        self.token_B.transfer(account, self.pool_account, input_amount)
        self.token_A.transfer(self.pool_account, account, output_amount)

        self.fees_accrued_B = self.fees_accrued_B + input_amount * self.fee

        return output_amount

    def get_output_amount(self, input_token_balance, output_token_balance, input_amount, D_offset=None):
        pass

    def get_input_amount(self, input_token, output_token, output_amount):
        pass

    def get_token_A_price(self):
        pass

    def get_token_B_price(self):
        pass

    # Given a target token A price, returns the amount of token B that needs to be swapped to increase
    # current token A price to the desired target
    def get_input_B_amount_from_target_price_A(self, target_price):
        pass

    # Given a target token B price, returns the amount of token A that needs to be swapped to increase
    # current token B price to the desired target
    def get_input_A_amount_from_target_price_B(self, target_price):
        pass

    def get_input_A_for_max_slippage(self, slippage, token_A_offset, token_B_offset):
        pass

    def get_input_B_for_max_slippage(self, slippage, token_A_offset, token_B_offset):
        pass

    def get_output_A_for_max_slippage(self, slippage, token_A_offset, token_B_offset):
        pass

    def get_output_B_for_max_slippage(self, slippage, token_A_offset, token_B_offset):
        pass

    def get_slippage_from_input_A(self, input_amount, debug):
        pass

    def get_slippage_from_input_B(self, input_amount, debug):
        pass

    def get_token_A_ownership(self, account):
        return self.token_A_balance() * self.get_liquidity(account) / self.lp_token.total_supply

    def get_token_B_ownership(self, account):
        return self.token_B_balance() * self.get_liquidity(account) / self.lp_token.total_supply

    def get_accrued_fees_in_token_A(self):
        return self.convert_to_A(self.fees_accrued_A, self.fees_accrued_B)

    def get_accrued_fees_in_token_B(self):
        return self.convert_to_B(self.fees_accrued_A, self.fees_accrued_B)

    # for AMM time weighted oracle
    def set_block_timestamp(self, iteration):
        self.block_timestamp = iteration * 86400
