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
        self.apr_max_value = 20

        self.plot_prefix = ''
        self.plot_file_description = ''

        return

    def prefixes_getter(self):
        pass
    def get_stoken_spot_price(self, chicken):
        pass
    def get_natural_rate(self, natural_rate, iteration):
        pass
    def get_pol_ratio_no_amm(self, chicken):
        pass
    def get_pol_ratio_with_amm(self, chicken):
        pass
    def get_reserve_ratio_no_amm(self, chicken):
        pass
    def get_reserve_ratio_with_amm(self, chicken):
        pass
    def distribute_yield(self, chicken, chicks, iteration):
        pass
    def bond(self, chicken, chicks, iteration):
        pass
    def chicken_in_out(self, chicken, chicks, iteration):
        pass
    def adjust_liquidity(self, chicken, chicks, amm_average_apr, iteration):
        pass
    def amm_arbitrage(self, chicken, chicks, iteration):
        pass
    def redemption_arbitrage(self, chicken, chicks, iteration):
        pass

class TesterBase(TesterInterface):
    def __init__(self):
        super().__init__()
        return

    def prefixes_getter(self):
        return self.plot_prefix, self.plot_file_description

    # TODO: iteration them
    def get_bonded_chicks(self, chicks):
        return list(filter(lambda chick: chick.bond_amount > 0, chicks))

    def get_not_bonded_chicks(self, chicks):
        return list(filter(lambda chick: chick.bond_amount == 0, chicks))

    def get_available_for_bonding_chicks(self, chicken, chicks):
        return list(filter(lambda chick: chick.bond_amount == 0 and chicken.token.balance_of(chick.account) > 0, chicks))

    def get_chicks_with_stoken(self, chicken, chicks, threshold=0):
        return list(filter(lambda chick: chicken.stoken.balance_of(chick.account) > threshold, chicks))

    def get_natural_rate(self, previous_natural_rate, iteration):
        np.random.seed(2021*iteration)
        shock_natural_rate = np.random.normal(0, SD_NATURAL_RATE)
        new_natural_rate = previous_natural_rate * (1 + shock_natural_rate)
        #print(f"previous natural rate: {previous_natural_rate:.3%}")
        #print(f"new natural rate:      {new_natural_rate:.3%}")

        return new_natural_rate

    def get_pol_ratio_no_amm(self, chicken):
        if chicken.stoken.total_supply == 0:
            return 1
        return chicken.pol_token_balance() / chicken.stoken.total_supply

    def get_pol_ratio_with_amm(self, chicken):
        if chicken.stoken.total_supply == 0:
            return 1

        amm_value = chicken.amm.get_value_in_token_A_of(chicken.pol_account)
        return (chicken.pol_token_balance() + amm_value) / chicken.stoken.total_supply

    def get_reserve_ratio_no_amm(self, chicken):
        if chicken.stoken.total_supply == 0:
            return 1
        return chicken.reserve_token_balance() / chicken.stoken.total_supply

    def get_reserve_ratio_with_amm(self, chicken):
        if chicken.stoken.total_supply == 0:
            return 1
        amm_value = chicken.amm.get_value_in_token_A_of(chicken.pol_account)
        return (chicken.reserve_token_balance() + amm_value) / chicken.stoken.total_supply


class TesterIssuanceBonds(TesterBase):
    def __init__(self):
        super().__init__()
        self.name = "Only bonds model"
        self.plot_prefix = '0_0'
        self.plot_file_description = 'bonds'

        self.initial_price = INITIAL_PRICE
        self.twap_period = TWAP_PERIOD

        self.external_yield = EXTERNAL_YIELD

        self.bond_mint_ratio = BOND_STOKEN_ISSUANCE_RATE
        self.bond_probability = 0.3
        self.bond_amount = INITIAL_AMOUNT / 10

        self.chicken_in_gamma_shape = CHICKEN_IN_GAMMA_SHAPE
        self.chicken_in_gamma_scale = CHICKEN_IN_GAMMA_SCALE
        self.chicken_out_probability = CHICKEN_OUT_PROBABILITY
        self.chicken_up_probability = CHICKEN_UP_PROBABILITY

        return

    def get_stoken_spot_price(self, chicken):
        stoken_supply = chicken.stoken.total_supply
        if stoken_supply == 0:
            # TODO: price!!
            return self.initial_price

        base_amount = chicken.reserve_token_balance()
        #print(f"reserve:       {base_amount:,.2f}")
        #print(f"sTOKEN supply: {stoken_supply:,.2f}")
        return base_amount / stoken_supply

    def get_stoken_twap(self, data, iteration):
        if iteration <= self.twap_period:
            return self.initial_price
        #print(data[iteration - self.twap_period : iteration]["stoken_price"])
        #print(f"average: {data[iteration - self.twap_period : iteration].mean()['stoken_price']:,.2f}")
        return data[iteration - self.twap_period : iteration].mean()["stoken_price"]

    def get_stoken_price(self, chicken, data, iteration):
        return self.get_stoken_twap(data, iteration)

    def get_pol_ratio(self, chicken):
        return self.get_pol_ratio_no_amm(chicken)

    def get_reserve_ratio(self, chicken):
        return self.get_reserve_ratio_no_amm(chicken)

    def get_stoken_apr_from_price(self, chicken, stoken_price):
        base_amount = chicken.coop_token_balance() + chicken.pol_token_balance()
        generated_yield = base_amount * self.external_yield
        stoken_supply = chicken.stoken.total_supply
        if stoken_supply == 0 or stoken_price == 0:
            return 0

        return generated_yield / (stoken_supply * stoken_price)

    def get_stoken_apr_spot(self, chicken):
        stoken_spot_price = self.get_stoken_spot_price(chicken)
        return self.get_stoken_apr_from_price(chicken, stoken_spot_price)

    def get_stoken_apr_twap(self, chicken, data, iteration):
        stoken_twap = self.get_stoken_twap(data, iteration)
        return self.get_stoken_apr_from_price(chicken, stoken_twap)

    def get_stoken_apr(self, chicken, data, iteration):
        return self.get_stoken_apr_twap(chicken, data, iteration)

    # https://www.desmos.com/calculator/taphbjrugg
    # See also: https://homepage.divms.uiowa.edu/~mbognar/applets/gamma.html
    def get_chicken_in_profit_percentage(self):
        return np.random.gamma(self.chicken_in_gamma_shape, self.chicken_in_gamma_scale, 1)[0]

    def distribute_yield(self, chicken, chicks, iteration):
        base_amount = chicken.reserve_token_balance()
        generated_yield = base_amount * self.external_yield / TIME_UNITS_PER_YEAR
        chicken.token.mint(chicken.pol_account, generated_yield)
        return

    def bond(self, chicken, chicks, iteration):
        np.random.seed(2022*iteration)
        np.random.shuffle(chicks)
        not_bonded_chicks = self.get_available_for_bonding_chicks(chicken, chicks)
        not_bonded_chicks_len = len(not_bonded_chicks)
        num_new_bonds = np.random.binomial(not_bonded_chicks_len, self.bond_probability)
        #print(f"available: {not_bonded_chicks_len:,.2f}")
        #print(f"bonding:   {num_new_bonds:,.2f}")
        total_bonded_amount = 0
        for chick in not_bonded_chicks[:num_new_bonds]:
            # TODO: randomize
            amount = min(
                chicken.token.balance_of(chick.account),
                self.bond_amount
            )
            if amount == 0:
                continue
            target_profit = self.get_chicken_in_profit_percentage()
            #print(f"amount: {amount:,.2f}")
            #print(f"profit: {target_profit:.3%}")
            chicken.bond(chick, amount, target_profit, iteration)
            total_bonded_amount = total_bonded_amount + amount
        return total_bonded_amount

    def get_claimable_stoken(self, chick, iteration, pol_ratio, stoken_price):
        claimable_stoken = min(
            chick.bond_amount * self.bond_mint_ratio * (iteration - chick.bond_time),
            chick.bond_amount / pol_ratio
        )

        return claimable_stoken

    def chicken_in_out(self, chicken, chicks, data, iteration):
        np.random.seed(2023*iteration)
        np.random.shuffle(chicks)
        # chicken in
        total_chicken_in_amount = 0
        total_chicken_in_foregone = 0
        bonded_chicks = self.get_bonded_chicks(chicks)
        #print(f"-- Chicken in")
        #print(f"Bonds: {len(bonded_chicks)}")
        for chick in bonded_chicks:
            assert iteration >= chick.bond_time
            pol_ratio = self.get_pol_ratio(chicken)
            assert pol_ratio == 0 or pol_ratio >= 1
            if pol_ratio == 0:
                pol_ratio = 1
            stoken_price = self.get_stoken_price(chicken, data, iteration)
            current_claimable_stoken = self.get_claimable_stoken(chick, iteration, pol_ratio, stoken_price)
            profit = current_claimable_stoken * stoken_price - chick.bond_amount
            target_profit = chick.bond_target_profit * chick.bond_amount
            if profit <= target_profit:
                """
                print("\n---")
                print(f"POL ratio: {pol_ratio:,.3%}")
                print(chick)
                print(f"bond:          {chick.bond_amount:,.2f}")
                print(f"target profit: {chick.bond_target_profit:.3%}")
                print(f"target profit: {target_profit:,.2f}")
                print(f"claimable:     {current_claimable_stoken:,.2f}")
                print(f"sTOKEN price:  {stoken_price:,.2f}")
                print(f"profit:        {profit:,.2f}")
                """
                continue
            # chicken up?
            if np.random.random() < self.chicken_up_probability:
                #print(f"\n-- Chicken up!")
                top_up_amount = min(chicken.token.balance_of(chick.account), chick.bond_amount)
                chicken.token.transfer(chick.account, chicken.coop_account, top_up_amount)
                current_claimable_stoken = current_claimable_stoken * (1 + top_up_amount / chick.bond_amount)
                chick.bond_amount = chick.bond_amount + top_up_amount
            """
            print("\n---")
            print(f"POL ratio: {pol_ratio:.3%}")
            print(chick)
            print(f"claimable:     {current_claimable_stoken:,.2f}")
            print(f"foregone:      {chick.bond_amount - current_claimable_stoken:,.2f}")
            print(f"stoken_price:  {stoken_price:,.2f}")
            print(f"bond:          {chick.bond_amount:,.2f}")
            print(f"target profit: {chick.bond_target_profit:.3%}")
            print(f"target profit: {target_profit:,.2f}")
            print(f"profit:        {profit:,.2f}")
            """

            total_chicken_in_amount = total_chicken_in_amount + current_claimable_stoken
            total_chicken_in_foregone = total_chicken_in_foregone + chick.bond_amount - current_claimable_stoken
            chicken.chicken_in(chick, current_claimable_stoken)

        # chicken out
        total_chicken_out_amount = 0
        bonded_chicks = self.get_bonded_chicks(chicks)
        #print(f"-- Chicken out")
        #print(f"Bonds: {len(bonded_chicks)}")
        for chick in bonded_chicks:
            if np.random.binomial(1, self.chicken_out_probability) == 0:
                continue
            total_chicken_out_amount = total_chicken_out_amount + chick.bond_amount
            """
            print("\n---")
            print(chick)
            print(f"claimable:     {current_claimable_stoken:,.2f}")
            print(f"bond:          {chick.bond_amount:,.2f}")
            """

            chicken.chicken_out(chick)

        return total_chicken_in_amount, total_chicken_in_foregone, total_chicken_out_amount


class TesterIssuanceBondsAMM_1(TesterIssuanceBonds):
    def __init__(self):
        super().__init__()
        self.name = "Bonds with AMM model - redeem against POL & AMM"
        self.plot_prefix = '0_1'
        self.plot_file_description = 'bonds_amm_1'

        self.price_max_value = 140

        self.max_slippage = MAX_SLIPPAGE
        self.amm_arbitrage_divergence = AMM_ARBITRAGE_DIVERGENCE
        self.chicken_in_amm_share = CHICKEN_IN_AMM_SHARE

        self.redemption_arbitrage_divergence = REDEMPTION_ARBITRAGE_DIVERGENCE

        return

    def get_stoken_spot_price(self, chicken):
        stoken_price = chicken.amm.get_token_B_price()
        if stoken_price == 0:
            return self.initial_price
        return stoken_price

    def get_stoken_apr_with_amm(self, chicken, stoken_apr, amm_apr):
        if chicken.stoken.total_supply == 0:
            return stoken_apr
        total_apr = stoken_apr + amm_apr * chicken.amm.get_value_in_token_B_of(chicken.pol_account) / chicken.stoken.total_supply
        return total_apr
    def get_stoken_apr_spot(self, chicken):
        base_apr = super().get_stoken_apr_spot(chicken)
        return self.get_stoken_apr_with_amm(chicken, base_apr, chicken.amm_iteration_apr)

    def get_stoken_apr_twap(self, chicken, data, iteration):
        base_apr = super().get_stoken_apr_twap(chicken, data, iteration)
        return self.get_stoken_apr_with_amm(chicken, base_apr, chicken.amm_average_apr)

    def get_pol_ratio(self, chicken):
        return self.get_pol_ratio_with_amm(chicken)

    def get_reserve_ratio(self, chicken):
        return self.get_reserve_ratio_with_amm(chicken)

    def get_chicken_in_liquidity_token_amount(self, total_chicken_in_foregone, stoken_spot_price):
        liquidity_token_amount = min(
            total_chicken_in_foregone * self.chicken_in_amm_share,
            stoken_spot_price * total_chicken_in_foregone / (stoken_spot_price + 1),
        )

        # TODO!!
        #liquidity_token_amount = liquidity_token_amount / 2

        return liquidity_token_amount

    def get_claimable_stoken(self, chick, iteration, pol_ratio, stoken_price):
        effective_bond_amount = chick.bond_amount * (1 - self.chicken_in_amm_share)
        claimable_stoken = min(
            effective_bond_amount * self.bond_mint_ratio * (iteration - chick.bond_time),
            effective_bond_amount / pol_ratio
        )

        return claimable_stoken

    def chicken_in_out(self, chicken, chicks, data, iteration):
        total_chicken_in_amount, total_chicken_in_foregone, total_chicken_out_amount = super().chicken_in_out(chicken, chicks, data, iteration)

        # Redirect part of bond to AMM
        stoken_spot_price = self.get_stoken_spot_price(chicken)
        if total_chicken_in_foregone > 0 and stoken_spot_price > 0:
            liquidity_token_amount = self.get_chicken_in_liquidity_token_amount(total_chicken_in_foregone, stoken_spot_price)

            if chicken.amm.token_A_balance() > 0:
                liquidity_stoken_amount = chicken.amm.get_B_amount_for_liquidity(liquidity_token_amount)
            else:
                liquidity_stoken_amount = liquidity_token_amount / stoken_spot_price
            assert liquidity_stoken_amount <= liquidity_token_amount
            assert liquidity_stoken_amount <= total_chicken_in_foregone - liquidity_token_amount


            """
            print(f"chicken in: {total_chicken_in_amount:,.2f}")
            print(f"foregone:   {total_chicken_in_foregone:,.2f}")
            print(f"price:      {stoken_spot_price:,.2f}")
            print(f"token:      {liquidity_token_amount:,.2f}")
            print(f"stoken:     {liquidity_stoken_amount:,.2f}")
            """
            chicken.stoken.mint(chicken.pol_account, liquidity_stoken_amount)
            chicken.amm.add_liquidity(chicken.pol_account, liquidity_token_amount, liquidity_stoken_amount)

        return total_chicken_in_amount, total_chicken_in_foregone, total_chicken_out_amount

    def adjust_liquidity(self, chicken, chicks, amm_average_apr, iteration):
        return

    def buy_stoken(self, chicken, chicks, reserve_ratio):
        #print(f"\n --> Buying sTOKEN")

        token_sell_amount = min(
            chicken.amm.get_input_A_for_max_slippage(self.max_slippage, 0, 0),
            chicken.amm.get_input_A_amount_from_target_price_B(reserve_ratio)
        )

        total_bought = 0
        remaining_amount = token_sell_amount
        for chick in chicks:
            # swap
            swap_amount = min(remaining_amount, chicken.token.balance_of(chick.account))
            if swap_amount < 0.1:
                continue
            bought_stoken_amount = chicken.amm.swap_A_for_B(chick.account, swap_amount)

            total_bought = total_bought + bought_stoken_amount
            remaining_amount = remaining_amount - swap_amount
            if remaining_amount < 0.1:
                break

        #print(f"total sTOKEN bought: {total_bought:,.2f}")
        #print(f"total TOKEN sold:    {token_sell_amount - remaining_amount:,.2f}")

        return

    def sell_stoken(self, chicken, chicks, reserve_ratio):
        #print(f"\n --> Selling sTOKEN")

        stoken_sell_amount = min(
            chicken.amm.get_input_B_for_max_slippage(self.max_slippage, 0, 0),
            chicken.amm.get_input_B_amount_from_target_price_A(1/reserve_ratio)
        )

        total_bought = 0
        remaining_amount = stoken_sell_amount
        for chick in chicks:
            # swap
            swap_amount = min(remaining_amount, chicken.stoken.balance_of(chick.account))
            if swap_amount < 0.1:
                continue
            bought_token_amount = chicken.amm.swap_B_for_A(chick.account, swap_amount)

            total_bought = total_bought + bought_token_amount
            remaining_amount = remaining_amount - swap_amount
            if remaining_amount < 0.1:
                break

        #print(f"total TOKEN bought: {total_bought:,.2f}")
        #print(f"total sTOKEN sold:  {stoken_sell_amount - remaining_amount:,.2f}")

        return

    def amm_arbitrage(self, chicken, chicks, iteration):
        if chicken.stoken.total_supply == 0:
            return
        reserve_ratio = self.get_reserve_ratio_no_amm(chicken)
        stoken_spot_price = self.get_stoken_spot_price(chicken)
        #print(f"stoken price: {stoken_spot_price:,.2f}")

        # if there’s more than 5% divergence, balance between AMM and reserve ratio
        if reserve_ratio < stoken_spot_price * (1 - self.amm_arbitrage_divergence):
            return self.sell_stoken(chicken, chicks, reserve_ratio)
        elif reserve_ratio > stoken_spot_price * (1 + self.amm_arbitrage_divergence):
            return self.buy_stoken(chicken, chicks, reserve_ratio)

    # POL and AMM pro-rata
    def redeem(self, chicken, chick, stoken_amount, pol_ratio):
        token_amount = stoken_amount * pol_ratio

        pol_token_balance = chicken.pol_token_balance()
        amm_value = chicken.amm.get_value_in_token_A_of(chicken.pol_account)
        total_value = pol_token_balance + amm_value

        pol_token_amount = token_amount * pol_token_balance / total_value
        lp_amount = token_amount / total_value * chicken.amm.get_liquidity(chicken.pol_account)
        """
        print("")
        print("---")
        print(chick)
        print(f"TOKEN bal before:  {chicken.token.balance_of(chick.account):,.2f}")
        print(f"sTOKEN bal before: {chicken.stoken.balance_of(chick.account):,.2f}")
        print("---")
        print(f"stoken_amount:     {stoken_amount:,.2f}")
        print(f"token_amount:      {token_amount:,.2f}")
        print(f"pol_token_balance: {pol_token_balance:,.2f}")
        print(f"pol amm_value:     {amm_value:,.2f}")
        print(f"pol total_value:   {total_value:,.2f}")
        print(f"pol_token_amount:  {pol_token_amount:,.2f}")
        print(f"lp_amount:         {lp_amount:,.2f}")
        """

        # burn sTOKEN
        chicken.stoken.burn(chick.account, stoken_amount)

        # transfer TOKEN
        chicken.token.transfer(chicken.pol_account, chick.account, pol_token_amount)

        # transfer LP token
        chicken.amm.lp_token.transfer(chicken.pol_account, chick.account, lp_amount)

        # withdraw liquidity
        amm_token_amount, amm_stoken_amount = chicken.amm.remove_liquidity(chick.account, lp_amount)
        #print(f"TOKEN from AMM:  {amm_token_amount:,.2f}")
        #print(f"sTOKEN from AMM: {amm_stoken_amount:,.2f}")

        # swap TOKEN for sTOKEN
        bought_stoken_amount = chicken.amm.swap_A_for_B(chick.account, pol_token_amount + amm_token_amount)

        redemption_result = amm_stoken_amount + bought_stoken_amount

        """
        print(f"redemption result: {redemption_result:,.2f}")
        print("---")
        print(f"TOKEN bal after:   {chicken.token.balance_of(chick.account):,.2f}")
        print(f"sTOKEN bal after:  {chicken.stoken.balance_of(chick.account):,.2f}")
        """

        assert stoken_amount < redemption_result
        return redemption_result

    def redemption_arbitrage(self, chicken, chicks, iteration):
        if chicken.stoken.total_supply == 0:
            return
        # redemption price
        pol_ratio = self.get_pol_ratio(chicken)
        stoken_spot_price = self.get_stoken_spot_price(chicken)

        # if there’s more than 5% divergence, balance between redemption and sTOKEN prices
        """
        print(f"\nPOL ratio:       {pol_ratio:,.2f}")
        print(f"Price:           {stoken_spot_price:,.2f}")
        print(f"Price threshold: {stoken_spot_price * (1 + self.redemption_arbitrage_divergence):,.2f}")
        """
        if pol_ratio > stoken_spot_price * (1 + self.redemption_arbitrage_divergence):
            token_swap_amount = min(
                chicken.amm.get_input_A_for_max_slippage(self.max_slippage, 0, 0),
                chicken.amm.get_input_A_amount_from_target_price_B(pol_ratio)
            )
            stoken_redemption_amount = token_swap_amount / pol_ratio
            remaining_amount = stoken_redemption_amount
            #for chick in self.get_chicks_with_stoken(chicken, chicks, threshold=pol_ratio * 10):
            for chick in self.get_chicks_with_stoken(chicken, chicks, threshold=10):
                chick_redemption_amount = min(
                    remaining_amount,
                    chicken.stoken.balance_of(chick.account)
                )
                redemption_result = self.redeem(chicken, chick, chick_redemption_amount, pol_ratio)

                remaining_amount = remaining_amount - chick_redemption_amount
                if remaining_amount < 0.1:
                    break

class TesterIssuanceBondsAMM_2(TesterIssuanceBondsAMM_1):
    def __init__(self):
        super().__init__()
        self.name = "Bonds with AMM model - redeem against POL"
        self.plot_prefix = '0_2'
        self.plot_file_description = 'bonds_amm_2'

        self.price_max_value = 100

        return

    def get_pol_ratio(self, chicken):
        return self.get_pol_ratio_no_amm(chicken)

    def get_reserve_ratio(self, chicken):
        return self.get_reserve_ratio_no_amm(chicken)

    def get_claimable_stoken(self, chick, iteration, pol_ratio, stoken_price):
        effective_bond_amount = chick.bond_amount * (1 - self.chicken_in_amm_share)
        claimable_stoken = min(
            effective_bond_amount * self.bond_mint_ratio * (iteration - chick.bond_time),
            effective_bond_amount / pol_ratio
        )
        # subtract to be minted sTOKEN
        claimable_stoken = claimable_stoken - chick.bond_amount * self.chicken_in_amm_share / stoken_price

        return claimable_stoken

    # Only POL, without AMM
    def redeem(self, chicken, chick, stoken_amount, pol_ratio):
        token_amount = stoken_amount * pol_ratio

        pol_token_balance = chicken.pol_token_balance()

        """
        print("")
        print("---")
        print(chick)
        print(f"TOKEN bal before:  {chicken.token.balance_of(chick.account):,.2f}")
        print(f"sTOKEN bal before: {chicken.stoken.balance_of(chick.account):,.2f}")
        print("---")
        print(f"stoken_amount:     {stoken_amount:,.2f}")
        print(f"token_amount:      {token_amount:,.2f}")
        print(f"pol_token_balance: {pol_token_balance:,.2f}")
        """

        # burn sTOKEN
        chicken.stoken.burn(chick.account, stoken_amount)

        # transfer TOKEN
        chicken.token.transfer(chicken.pol_account, chick.account, token_amount)

        # swap TOKEN for sTOKEN
        bought_stoken_amount = chicken.amm.swap_A_for_B(chick.account, token_amount)

        redemption_result = bought_stoken_amount

        """
        print(f"redemption result: {redemption_result:,.2f}")
        print("---")
        print(f"TOKEN bal after:   {chicken.token.balance_of(chick.account):,.2f}")
        print(f"sTOKEN bal after:  {chicken.stoken.balance_of(chick.account):,.2f}")
        """

        assert stoken_amount < redemption_result
        return redemption_result

class TesterIssuanceBondsAMM_3(TesterIssuanceBondsAMM_1):
    def __init__(self):
        super().__init__()
        self.name = "Bonds with AMM model - redeem POL then AMM"
        self.plot_prefix = '0_3'
        self.plot_file_description = 'bonds_amm_3'

        self.price_max_value = 140

        return

    def get_pol_ratio(self, chicken):
        return self.get_pol_ratio_with_amm(chicken)

    def get_reserve_ratio(self, chicken):
        return self.get_reserve_ratio_no_amm(chicken)

    def get_claimable_stoken(self, chick, iteration, pol_ratio, stoken_price):
        effective_bond_amount = chick.bond_amount * (1 - self.chicken_in_amm_share)
        claimable_stoken = min(
            effective_bond_amount * self.bond_mint_ratio * (iteration - chick.bond_time),
            effective_bond_amount / pol_ratio
        )

        return claimable_stoken

    # First POL, then AMM
    def redeem(self, chicken, chick, stoken_amount, pol_ratio):
        token_amount = stoken_amount * pol_ratio

        pol_token_balance = chicken.pol_token_balance()
        """
        print("")
        print("---")
        print(chick)
        print(f"TOKEN bal before:  {chicken.token.balance_of(chick.account):,.2f}")
        print(f"sTOKEN bal before: {chicken.stoken.balance_of(chick.account):,.2f}")
        print("---")
        print(f"stoken_amount:     {stoken_amount:,.2f}")
        print(f"token_amount:      {token_amount:,.2f}")
        print(f"pol_token_balance: {pol_token_balance:,.2f}")
        #print(f"pol amm_value:     {amm_value:,.2f}")
        #print(f"pol total_value:   {total_value:,.2f}")
        #print(f"pol_token_amount:  {pol_token_amount:,.2f}")
        #print(f"lp_amount:         {lp_amount:,.2f}")
        """
        remaining_token_amount = token_amount
        pol_token_amount = 0
        if pol_token_balance > 0:
            pol_token_amount = min(
                token_amount,
                pol_token_balance
            )
            remaining_token_amount = remaining_token_amount - pol_token_amount

            # burn sTOKEN
            chicken.stoken.burn(chick.account, stoken_amount)

            # transfer TOKEN
            chicken.token.transfer(chicken.pol_account, chick.account, pol_token_amount)

        if remaining_token_amount > 0:
            amm_value = chicken.amm.get_value_in_token_A_of(chicken.pol_account)
            lp_amount = token_amount / amm_value * chicken.amm.get_liquidity(chicken.pol_account)

            # transfer LP token
            chicken.amm.lp_token.transfer(chicken.pol_account, chick.account, lp_amount)

            # withdraw liquidity
            amm_token_amount, amm_stoken_amount = chicken.amm.remove_liquidity(chick.account, lp_amount)
            #print(f"TOKEN from AMM:  {amm_token_amount:,.2f}")
            #print(f"sTOKEN from AMM: {amm_stoken_amount:,.2f}")
        else:
            amm_token_amount = 0
            amm_stoken_amount = 0

        # swap TOKEN for sTOKEN
        bought_stoken_amount = chicken.amm.swap_A_for_B(chick.account, pol_token_amount + amm_token_amount)

        redemption_result = amm_stoken_amount + bought_stoken_amount

        """
        print(f"redemption result: {redemption_result:,.2f}")
        print("---")
        print(f"TOKEN bal after:   {chicken.token.balance_of(chick.account):,.2f}")
        print(f"sTOKEN bal after:  {chicken.stoken.balance_of(chick.account):,.2f}")
        """

        assert stoken_amount < redemption_result
        return redemption_result

class TesterIssuanceBondsAMM_4(TesterIssuanceBondsAMM_1):
    def __init__(self):
        super().__init__()
        self.name = "Bonds with AMM model - partially backed"
        self.plot_prefix = '0_4'
        self.plot_file_description = 'bonds_amm_4'
