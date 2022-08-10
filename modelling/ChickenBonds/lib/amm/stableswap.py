import math
import numpy as np
from lib.amm.amm_base import *

class StableSwapPool(AmmBase):
    def __init__(self, pool_account, token_A, token_B, fee, amplification_factor):
        super().__init__(pool_account, token_A, token_B, fee)
        self.amplification_factor = amplification_factor
        self.D = 0

    def get_A_amount_for_liquidity(self, token_B_amount):
        token_A_reserve = self.token_A_balance()
        token_B_reserve = self.token_B_balance()
        return token_B_amount * token_A_reserve / token_B_reserve
    def get_B_amount_for_liquidity(self, token_A_amount):
        token_A_reserve = self.token_A_balance()
        token_B_reserve = self.token_B_balance()
        return token_A_amount * token_B_reserve / token_A_reserve

    # This is only guaranteed to work if A >= 0.25, as otherwise Q^2+P^3 may be < 0.
    # From: https://en.wikipedia.org/wiki/Cubic_equation#Cardano's_formula
    # If 4p^3+27q^2<0, there are three real roots, but Galois theory allows proving that,
    # if there is no rational root, the roots cannot be expressed by an algebraic expression involving only real numbers.
    def get_D_from_x_y(self, x, y):
        A = self.amplification_factor
        p = 4*(4*A -1)*x*y
        q = -16*A*(x+y)*x*y

        P = p/3
        Q = q/2
        d = math.sqrt(Q**2 + P**3)
        """
        print(" -- \033[33mget_D_from_x_y\033[0m")
        print(f"x: {x:,.2f}")
        print(f"y: {y:,.2f}")
        print(f"A: {A:,.2f}")
        print(f"p: {p:,.2f}")
        print(f"q: {q:,.2f}")
        print(f"P: {P:,.2f}")
        print(f"Q: {Q:,.2f}")
        print(f"d: {d:,.2f}")
        print(f"-Q+d: {-Q+d:,.2f}")
        print(f"-Q-d: {-Q-d:,.2f}")
        print(f"(-Q+d)^(1/3): {np.cbrt(-Q+d):,.2f}")
        print(f"-Q-d: {-Q-d:,.2f}")
        print(f"(-Q-d)^(1/3): {np.cbrt(-Q-d):,.2f}")
        print(f"D: {np.cbrt(-Q + d) - np.cbrt(Q + d):,.2f}")
        """

        return np.cbrt(-Q + d) - np.cbrt(Q + d)
    def get_D(self):
        x = self.token_A_balance()
        y = self.token_B_balance()
        return self.get_D_from_x_y(x, y)

    def udpate_after_liquidity_movement(self):
            self.D = self.get_D()

    def add_liquidity(self, account, token_A_amount, max_token_B_amount):
        total_liquidity = self.get_total_liquidity()
        if total_liquidity == 0: # initial liquidity
            assert token_A_amount > 1.0
            assert max_token_B_amount >= token_A_amount

            token_B_amount = token_A_amount
            self.token_A.transfer(account, self.pool_account, token_A_amount)
            self.token_B.transfer(account, self.pool_account, token_B_amount)

            self.lp_token.mint(account, token_A_amount)

            self.D = 2 * token_A_amount
        else:
            token_B_amount = self.get_B_amount_for_liquidity(token_A_amount)
            """
            print(f"token_A_amount:     {token_A_amount:,.2f}")
            print(f"token_B_amount:     {token_B_amount:,.2f}")
            print(f"max_token_B_amount: {max_token_B_amount:,.2f}")
            """
            #assert token_B_amount <= max_token_B_amount

            token_A_reserve = self.token_A_balance()
            liquidity_minted = token_A_amount * total_liquidity / token_A_reserve

            self.token_A.transfer(account, self.pool_account, token_A_amount)
            self.token_B.transfer(account, self.pool_account, token_B_amount)

            self.lp_token.mint(account, liquidity_minted)

        self.udpate_after_liquidity_movement()

        return token_A_amount, token_B_amount

    def add_liquidity_single_A(self, account, token_A_amount, max_slippage):
        initial_token_B_balance = self.token_B.balance_of(account)
        token_A_reserve = self.token_A_balance()
        token_B_reserve = self.token_B_balance()
        # TODO: this is an approximation!
        # Because of that, we lower it by 1%, to avoid errors
        amount_to_add = token_A_amount * token_A_reserve / (token_A_reserve + token_B_reserve) * 0.99
        amount_to_swap = token_A_amount - amount_to_add
        amount_A_max_slippage = self.get_input_A_for_max_slippage(max_slippage, 0, 0)
        """
        print("")
        print("-- Before")
        print(self)
        print(f"total:   {token_A_amount:,.2f}")
        print(f"add A:   {amount_to_add:,.2f}")
        print(f"to swap: {amount_to_swap:,.2f}")
        print(f"amount A max slippage: {amount_A_max_slippage:,.2f}")
        print("")
        print(f"A: {self.token_A_balance():,.2f}")
        print(f"B: {self.token_B_balance():,.2f}")
        print("")
        """
        if amount_to_swap > amount_A_max_slippage:
            amount_to_add = amount_to_add * amount_A_max_slippage / amount_to_swap
            amount_to_swap = amount_A_max_slippage
        token_B_amount = self.swap_A_for_B(account, amount_to_swap)
        #print(f"\033[35m[Add liquidity]\033[0m Swapped {amount_to_swap:.2f} DEBT tokens for {token_B_amount:.2f} eDEBT tokens")
        """
        print(f"A: {self.token_A_balance():,.2f}")
        print(f"B: {self.token_B_balance():,.2f}")
        print("")
        print("")
        print("-- After swap")
        print(self)
        print(f"total: {token_A_amount:,.2f}")
        print(f"add A: {amount_to_add:,.2f}")
        print(f"swap:  {amount_to_swap:,.2f}")
        print(f"add B: {token_B_amount:,.2f}")
        print("")
        #assert token_B_amount / amount_to_swap < 1.1
        """
        self.add_liquidity(account, amount_to_add, token_B_amount)
        """
        print("")
        print("-- After add")
        print(self)
        print("")
        """

        # Swap back the leftovers
        final_token_B_balance = self.token_B.balance_of(account)
        if final_token_B_balance > initial_token_B_balance:
            self.swap_B_for_A(account, final_token_B_balance - initial_token_B_balance)

        """
        print(f"initial_token_B_balance: {initial_token_B_balance:,.2f}")
        print(f"final_token_B_balance: {final_token_B_balance:,.2f}")
        print("")
        print("-- After swap back")
        print(f"B bal after swap back: {self.token_B.balance_of(account):,.2f}")
        print(self)
        print("")
        """

        token_A_amount = self.token_A_balance() - token_A_reserve
        token_B_amount = self.token_B_balance() - token_B_reserve
        return token_A_amount, token_B_amount

    def remove_liquidity(self, account, liquidity):
        result = super().remove_liquidity(account, liquidity)
        self.udpate_after_liquidity_movement()
        return result
    def remove_all_liquidity(self, account):
        result = super().remove_all_liquidity(account)
        self.udpate_after_liquidity_movement()
        return result
    def remove_liquidity_single_A(self, account, token_A_amount, max_slippage):
        result = super().remove_liquidity_single_A(account, token_A_amount, max_slippage)
        self.udpate_after_liquidity_movement()
        return result

    def get_output_amount(self, input_balance, output_balance, input_amount, D=None):
        if input_amount < 1e-6:
            return 0.0
        x = input_balance
        y = output_balance

        input_amount_with_fee = input_amount * (1 - self.fee)
        # let’s shorten notation for the big formula
        X = x + input_amount_with_fee
        A = self.amplification_factor
        if not D:
            D = self.D
        """
        print(" -- get_output_amount")
        b = 4*A * X**2 - (4*A-1)*D*X
        print("")
        print(f"in:  {input_amount:,.2f}")
        print(f"in-f:  {input_amount_with_fee:,.2f}")
        print(f"x: {x:,.2f}")
        print(f"X: {X:,.2f}")
        print(f"y: {y:,.2f}")
        print(f"A: {A:,.2f}")
        print(f"D: {D:,.2f}")
        print(f"b: {b:,.2f}")
        print(f"disc:  {b**2 + 4*A*D**3*X:,.2f}")
        print(f"sqrt:  {math.sqrt(b**2 + 4*A*D**3*X):,.2f}")
        print(f"num:  {(-b + math.sqrt(b**2 + 4*A*D**3*X)):,.2f}")
        print(f"den:  {(8 * A * X):,.2f}")
        print(f"y_1:  {(-b + math.sqrt(b**2 + 4*A*D**3*X)) / (8 * A * X):,.2f}")
        print(f"out:  {y - (-b + math.sqrt(b**2 + 4*A*D**3*X)) / (8 * A * X):,.2f}")
        print(f"disc: {(X/2)**2 - (4*A-1)/A*D/8*X + ((4*A-1)/A*D/8)**2 + D/16*D/A*D/X:,.2f}")
        print(f"sqrt: {math.sqrt((X/2)**2 - (4*A-1)/A*D/8*X + ((4*A-1)/A*D/8)**2 + D/16*D/A*D/X):,.2f}")
        print(f"b':   {-b / (8 * A * X):,.2f}")
        #print(f"y_1:  {-b / (8 * A * X) + math.sqrt((X/2)**2 - (4*A-1)/A*D/8*X + ((4*A-1)/A*D/8)**2 + D/16*D/A*D/X):,.2f}")
        print(f"y_1:  {(-X/2 + D/8/A*(4*A-1) + math.sqrt((X/2)**2 - (4*A-1)/A*D/8*X + ((4*A-1)/A*D/8)**2 + D/16*D/A*D/X)):,.2f}")
        print(f"out:  {y - (-b / (8 * A * X) + math.sqrt((X/2)**2 - (4*A-1)/A*D/8*X + ((4*A-1)/A*D/8)**2 + D/16*D/A*D/X)):,.2f}")
        print("")
        #return y - (-b + math.sqrt(b**2 + 4*A*D**3*X)) / (8 * A * X)
        """
        output_amount = y - (-X/2 + D/8/A*(4*A-1) + math.sqrt((X/2)**2 - (4*A-1)/A*D/8*X + ((4*A-1)/A*D/8)**2 + D/16*D/A*D/X))
        """
        print(" -- get_output_amount")
        print(f"in:  {input_amount:,.2f}")
        print(f"in-f:  {input_amount_with_fee:,.2f}")
        print(f"out:  {output_amount:,.2f}")
        """
        assert output_amount > 0

        return output_amount

    def get_input_amount(self, input_token, output_token, output_amount):
        if output_amount == 0.0:
            return 0.0
        x = input_token.balance_of(self.pool_account)
        y = output_token.balance_of(self.pool_account)

        Y = y - output_amount
        A = self.amplification_factor
        D = self.D
        #b = 4*A * Y**2 - (4*A-1)*D*Y
        #input_amount =  (-b + math.sqrt(b**2 + 4*A*D**3*Y)) / (8 * A * Y) - x
        input_amount = -Y/2 + D/8/A*(4*A-1) + math.sqrt((Y/2)**2 - (4*A-1)/A*D/8*Y + ((4*A-1)/A*D/8)**2 + D/16*D/A*D/Y) - x
        assert input_amount > 0

        """
        print(" -- get_input_amount")
        print(f"x: {x:,.2f}")
        print(f"y: {y:,.2f}")
        print(f"output_amount: {output_amount:,.2f}")
        print(f"Y: {Y:,.2f}")
        b = 4*A * Y**2 - (4*A-1)*D*Y
        print(f"new x: {(-b + math.sqrt(b**2 + 4*A*D**3*Y)) / (8 * A * Y):,.2f}")
        print(f"input_amount: {(-b + math.sqrt(b**2 + 4*A*D**3*Y)) / (8 * A * Y) - x:,.2f}")
        print(f"new x: {-Y/2 + D/8/A*(4*A-1) + math.sqrt((Y/2)**2 - (4*A-1)/A*D/8*Y + ((4*A-1)/A*D/8)**2 + D/16*D/A*D/Y):,.2f}")
        print(f"input_amount: {input_amount:,.2f}")
        assert abs(input_amount - ((-b + math.sqrt(b**2 + 4*A*D**3*Y)) / (8 * A * Y) - x)) < 0.0001
        """
        return input_amount / (1 - self.fee)

    def get_price(self, x, y, D=None):
        if x == 0 or y == 0:
            return 0
        A = self.amplification_factor
        if not D:
            D = self.D
        """
        print(" -- get_price")
        print(f"x: {x:,.2f}")
        print(f"y: {y:,.2f}")
        print(f"A: {A:,.2f}")
        print(f"D: {D:,.2f}")
        print(f"price: {((4 * A * (2*x + y - D) + D)*y) / ((4 * A * (x + 2*y - D) + D)*x):,.2f}")
        """
        return ((4 * A * (2*x + y - D) + D)*y) / ((4 * A * (x + 2*y - D) + D)*x)
    def get_token_A_price(self):
        x = self.token_A_balance()
        y = self.token_B_balance()
        return self.get_price(x, y)
    def get_token_B_price(self):
        x = self.token_A_balance()
        y = self.token_B_balance()
        return self.get_price(y, x)

    # Slippage

    # slippage from input
    def get_slippage_from_input(self, initial_price, input_amount, token_A_balance, token_B_balance, D_offset):
        output_amount = self.get_output_amount(token_A_balance, token_B_balance, input_amount, D_offset)
        new_price = self.get_price(token_A_balance + input_amount, token_B_balance - output_amount, D_offset)
        slippage = 1 - new_price / initial_price
        """
        print(" -- get_slippage_from_input")
        print(f"initial_price: {initial_price:,.2f}")
        print(f"input_amount:  {input_amount:,.2f}")
        print(f"x: {token_A_balance:,.2f}")
        print(f"y: {token_B_balance:,.2f}")
        print(f"Dx: {input_amount:,.2f}")
        print(f"Dy: {-output_amount:,.2f}")
        print(f"new price: {new_price:,.2f}")
        print(f"slippage: {slippage:.3%}")
        """
        return slippage

    def get_input_for_max_slippage(self, initial_price, max_slippage, token_A_balance, token_B_balance, D_offset):
        #print("")
        #print("-- get input price:")
        input_amount = token_A_balance / 2
        """
        print(" -- get_input_for_max_slippage")
        print(f"initial_price: {initial_price:,.2f}")
        print(f"max_slippage: {max_slippage:.3%}")
        print(f"A bal: {token_A_balance:,.2f}")
        print(f"B bal: {token_B_balance:,.2f}")
        """
        slippage = self.get_slippage_from_input(initial_price, input_amount, token_A_balance, token_B_balance, D_offset)
        i = 0
        while slippage > max_slippage:
            i = i + 1
            input_amount = input_amount * 0.8
            """
            print(f"\nIteration {i}")
            print(f"slippage: {slippage:.3%}")
            print(f"input: {input_amount:,.2f}")
            """
            slippage = self.get_slippage_from_input(initial_price, input_amount, token_A_balance, token_B_balance, D_offset)
            assert i < 30

        """
        print("")
        print(f"\033[32m Final slippage: {slippage:.3%} \033[0m")
        print(f"\033[33m Final input:   {input_amount:,.2f} \033[0m")
        print("")
        """

        return input_amount / (1 - self.fee)

    def get_input_A_for_max_slippage(self, max_slippage, token_A_offset, token_B_offset):
        initial_price = self.get_token_A_price()
        initial_token_A_balance = self.token_A_balance() + token_A_offset
        initial_token_B_balance = self.token_B_balance() + token_B_offset
        D_offset = self.get_D_from_x_y(initial_token_A_balance, initial_token_B_balance)
        return self.get_input_for_max_slippage(initial_price, max_slippage, initial_token_A_balance, initial_token_B_balance, D_offset)

    def get_input_B_for_max_slippage(self, max_slippage, token_A_offset, token_B_offset):
        initial_price = self.get_token_B_price()
        initial_token_A_balance = self.token_A_balance() + token_A_offset
        initial_token_B_balance = self.token_B_balance() + token_B_offset
        D_offset = self.get_D_from_x_y(initial_token_A_balance, initial_token_B_balance)
        """
        print(" -- get_input_B_for_max_slippage")
        print(f"max_slippage: {max_slippage:.3%}")
        print(f"offset A: {token_A_offset:,.2f}")
        print(f"offset B: {token_B_offset:,.2f}")
        print(f"price: {initial_price:,.2f}")
        """
        return self.get_input_for_max_slippage(initial_price, max_slippage, initial_token_B_balance, initial_token_A_balance, D_offset)

    # slippage from output
    def get_slippage_from_output(self, initial_price, output_amount, token_A, token_B, token_A_offset, token_B_offset):
        initial_token_A_balance = token_A.balance_of(self.pool_account) + token_A_offset
        initial_token_B_balance = token_B.balance_of(self.pool_account) + token_B_offset
        input_amount = self.get_input_amount(token_A, token_B, output_amount)
        new_price = self.get_price(initial_token_A_balance + input_amount, initial_token_B_balance - output_amount)
        slippage = 1 - new_price / initial_price
        """
        print(f"initial_price: {initial_price:,.2f}")
        print(f"x: {initial_token_A_balance:,.2f}")
        print(f"y: {initial_token_B_balance:,.2f}")
        print(f"Dx: {input_amount:,.2f}")
        print(f"Dy: {-output_amount:,.2f}")
        print(f"new price: {new_price:,.2f}")
        print(f"slippage: {slippage:.3%}")
        """
        return slippage

    def get_output_for_max_slippage(self, initial_price, max_slippage, token_A, token_B, token_A_offset, token_B_offset):
        #print("")
        #print("-- get input price:")
        output_amount = token_B.balance_of(self.pool_account) / 2
        slippage = self.get_slippage_from_output(initial_price, output_amount, token_A, token_B, token_A_offset, token_B_offset)
        i = 0
        while slippage > max_slippage:
            i = i + 1
            output_amount = output_amount * 0.8
            """
            print(f"Iteration {i}")
            print(f"slippage: {slippage:.3%}")
            print(f"output: {output_amount:,.2f}")
            """
            slippage = self.get_slippage_from_output(initial_price, output_amount, token_A, token_B, token_A_offset, token_B_offset)
            #assert i < 30
            if i > 30:
                #print(self)
                return 0

        """
        print("")
        print(f"\033[32m Final slippage: {slippage:.3%} \033[0m")
        print(f"\033[34m Final output:   {output_amount:,.2f} \033[0m")
        print("")
        """

        assert slippage > 0

        return output_amount

    def get_output_A_for_max_slippage(self, max_slippage, token_A_offset, token_B_offset):
        initial_price = self.get_token_B_price()
        return self.get_output_for_max_slippage(initial_price, max_slippage, self.token_B, self.token_A, token_A_offset, token_B_offset)

    def get_output_B_for_max_slippage(self, max_slippage, token_A_offset, token_B_offset):
        initial_price = self.get_token_A_price()
        return self.get_output_for_max_slippage(initial_price, max_slippage, self.token_A, self.token_B, token_A_offset, token_B_offset)
