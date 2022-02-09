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

        self.chicken_in_counter = 0
        self.chicken_up_counter = 0
        self.chicken_out_counter = 0
        self.chicken_up_locked = 0

        return

    def init(self, chicks):
        pass

    def prefixes_getter(self):
        pass

    def get_stoken_spot_price(self, chicken):
        pass

    def get_natural_rate(self, natural_rate, iteration):
        pass

    def get_stoken_apr_spot(self, chicken):
        pass

    def get_stoken_apr_twap(self, chicken, data, iteration):
        pass

    def get_stoken_apr(self, chicken, data, iteration):
        pass

    def get_pol_ratio_no_amm(self, chicken):
        pass

    def get_pol_ratio_with_amm(self, chicken):
        pass
    def get_pol_ratio(self, chicken):
        pass
    def get_reserve_ratio_no_amm(self, chicken):
        pass

    def get_reserve_ratio_with_amm(self, chicken):
        pass
    def get_reserve_ratio(self, chicken):
        pass
    def distribute_yield(self, chicken, chicks, iteration):
        pass

    def bond(self, chicken, chicks, iteration):
        pass

    def update_chicken(self, chicken, chicks, iteration):
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
        self.price_max_value = 40
        return

    def prefixes_getter(self):
        return self.plot_prefix, self.plot_file_description

    # TODO: index them
    def get_bonded_chicks(self, chicks):
        return list(filter(lambda chick: chick.bond_amount > 0, chicks))

    def get_not_bonded_chicks(self, chicks):
        return list(filter(lambda chick: chick.bond_amount == 0, chicks))

    def get_available_for_bonding_chicks(self, chicken, chicks):
        return list(
            filter(lambda chick: chick.bond_amount == 0 and chicken.token.balance_of(chick.account) > 0, chicks))

    def get_chicks_with_stoken(self, chicken, chicks, threshold=0):
        return list(filter(lambda chick: chicken.stoken.balance_of(chick.account) > threshold, chicks))

    def get_bond_cap(self, effective_bond_amount, pol_ratio):
        if pol_ratio == 0:
            return 999999999
        return effective_bond_amount / pol_ratio

    def get_natural_rate(self, previous_natural_rate, iteration):
        np.random.seed(2021 * iteration)
        shock_natural_rate = np.random.normal(0, SD_NATURAL_RATE)
        new_natural_rate = previous_natural_rate * (1 + shock_natural_rate)
        # print(f"previous natural rate: {previous_natural_rate:.3%}")
        # print(f"new natural rate:      {new_natural_rate:.3%}")

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
        self.bond_probability = BOND_PROBABILITY
        # TODO: make it deterministic? Make it different for each user?
        self.bond_amount = np.random.randint(BOND_AMOUNT[0], BOND_AMOUNT[1], 1)[0]
        self.chicken_in_gamma_shape = CHICKEN_IN_GAMMA[0]
        self.chicken_in_gamma_scale = CHICKEN_IN_GAMMA[1]
        self.chicken_out_probability = CHICKEN_OUT_PROBABILITY
        self.chicken_up_probability = CHICKEN_UP_PROBABILITY

        return

    def get_stoken_spot_price(self, chicken):
        """
        Calculate the fair spot price of sLQTY. The price is determined by the price floor plus a premium.
        @param chicken: The reserves.
        @return: The sLQTY spot price.
        """

        stoken_supply = chicken.stoken.total_supply
        if stoken_supply == 0:
            return self.initial_price

        base_amount = chicken.pol_token_balance()
        mu = base_amount * PREMIUM_MU
        sigma = mu * PREMIUM_SIGMA

        # Different methods to estimate the premium of sLQTY tokens.
        premium_mapper = {"normal_dist": np.random.normal(mu, sigma, 1) / stoken_supply,
                          "perpetuity": (chicken.coop_token_balance() * EXTERNAL_YIELD) ** (1 / TIME_UNITS_PER_YEAR),
                          "coop_balance": chicken.coop_token_balance() / stoken_supply,
                          }

        # Different methods to include volatility in the price.
        volatility_mapper = {"None": 0,
                             "bounded": min(np.random.normal(VOLA_MU, VOLA_SIGMA, 1), base_amount / stoken_supply),
                             "unbounded": np.random.normal(VOLA_MU, VOLA_SIGMA, 1),
                             }

        total_price = (base_amount / stoken_supply) \
                      + premium_mapper.get(PRICE_PREMIUM, 0) \
                      + volatility_mapper.get(PRICE_VOLATILITY, 0)

        return total_price

    def get_stoken_twap(self, data, iteration):
        if iteration <= self.twap_period:
            return self.initial_price
        # print(data[iteration - self.twap_period : iteration]["stoken_price"])
        # print(f"average: {data[iteration - self.twap_period : iteration].mean()['stoken_price']:,.2f}")
        return data[iteration - self.twap_period: iteration].mean()["stoken_price"]

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

    # There’s no need to use the compound formula, because the generated yield is added to the POL on each iteration
    # So it’s already being compounded
    def distribute_yield(self, chicken, chicks, iteration):
        base_amount = chicken.reserve_token_balance()

        generated_yield = base_amount * self.external_yield / TIME_UNITS_PER_YEAR

        chicken.token.mint(chicken.pol_account, generated_yield)
        return

    def bond(self, chicken, chicks, iteration):
        np.random.seed(2022 * iteration)
        np.random.shuffle(chicks)
        not_bonded_chicks = self.get_available_for_bonding_chicks(chicken, chicks)
        not_bonded_chicks_len = len(not_bonded_chicks)
        num_new_bonds = np.random.binomial(not_bonded_chicks_len, self.bond_probability)
        # print(f"available: {not_bonded_chicks_len:,.2f}")
        # print(f"bonding:   {num_new_bonds:,.2f}")
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
            # print(f"amount: {amount:,.2f}")
            # print(f"profit: {target_profit:.3%}")
            chicken.bond(chick, amount, target_profit, iteration)
            total_bonded_amount = total_bonded_amount + amount
        return total_bonded_amount

    def get_claimable_stoken(self, chicken, chick, iteration, pol_ratio):
        bond_cap = self.get_bond_cap(chick.bond_amount, pol_ratio)
        accumulated_amount = self.get_accumulated_stoken(chick, iteration)
        claimable_stoken = min(
            accumulated_amount,
            bond_cap
        )
        # claimable stoken is returned twice because with the toll the effective amount can differ
        return claimable_stoken, bond_cap, claimable_stoken, 0, 0

    def is_bootstrap_chicken_in(self, chick, iteration):
        return iteration == BOOTSTRAP_ITERATION and chick.bond_time == 0

    def get_accumulated_stoken(self, chick, iteration):
        """ Calculated the total amount of accumulated sLQTY tokens of a user.

        @param chick: The user.
        @param iteration: The iteration step of the simulation.
        @return: Total amount of theoretical claimable sLQTY token.
        """
        return chick.bond_amount * self.bond_mint_ratio * (iteration - chick.bond_time)

    def update_chicken(self, chicken, chicks, data, iteration):
        """ Update the state of each user. Users may:
            - chicken-out
            - chicken-in
            - chicken-up
        with predefined probabilities.

        @param chicken: The resources
        @param chicks: All users
        @param data: Logging data
        @param iteration: The iteration step
        """

        np.random.seed(2023 * iteration)
        np.random.shuffle(chicks)

        total_chicken_in_amount = 0
        total_chicken_out_amount = 0
        total_chicken_in_foregone = 0
        total_chicken_up_amount = 0
        bonded_chicks = self.get_bonded_chicks(chicks)
        print(f"Bonded Chicks: {len(bonded_chicks)}")

        for chick in bonded_chicks:

            assert iteration >= chick.bond_time
            pol_ratio = self.get_pol_ratio(chicken)
            assert pol_ratio == 0 or pol_ratio >= 1
            if pol_ratio == 0:
                pol_ratio = 1

            # ----------- Chicken-out --------------------
            # Check if chicken-out conditions are met and eventually chicken-out
            total_chicken_out_amount += self.chicken_out(chicken, chick, iteration, data)

            # ----------- Chicken-in --------------------
            # Check if chicken-in conditions are met and eventually chicken-in
            new_chicken_in_amount, new_chicken_in_forgone, _, _ = \
                self.chicken_in(chicken, chick, iteration, data)
            total_chicken_in_amount += new_chicken_in_amount
            total_chicken_in_foregone += new_chicken_in_forgone

            # ----------- Chicken-up --------------------
            # Check if chicken-up conditions are met and eventually chicken-up
            total_chicken_up_amount += self.chicken_up(chicken, chick, iteration, data)

        print("Out:", self.chicken_out_counter)
        print("In:", self.chicken_in_counter)
        print("Up:", self.chicken_up_counter)
        print("Locked:", self.chicken_up_locked)
        self.chicken_up_locked = 0

        return

    def chicken_in(self, chicken, chick, iteration, data):
        """ User may chicken-in if the have already exceeded the break-even
        point of their investment and not yet exceeded the bonding cap.

        @param chicken: The resources.
        @param chick: The user
        @param iteration: The iteration step
        @param data: Logging data
        @return: Amount of new claimable sLQTY and foregone amount.
        """

        pol_ratio = self.get_pol_ratio(chicken)
        mintable_amount, bond_cap, claimable_stoken, amm_token_amount, amm_stoken_amount = \
            self.get_claimable_stoken(chicken, chick, iteration, pol_ratio)

        # use actual stoken price instead of weighted average
        # stoken_price = self.get_stoken_price(chicken, data, iteration)
        stoken_price = self.get_stoken_spot_price(chicken)
        profit = claimable_stoken * stoken_price - chick.bond_amount
        target_profit = chick.bond_target_profit * chick.bond_amount

        max_claimable_stoken = self.get_accumulated_stoken(chick, iteration)

        # If the chicks profit are below their target_profit,
        # do neither chicken-in nor chicken-up.
        if profit <= target_profit:
            self.chicken_up_locked += 1
        if profit <= target_profit and not self.is_bootstrap_chicken_in(chick, iteration):
            return 0, 0, 0, 0
        # If the user reached the sLQTY cap, certainly chicken-up.
        if max_claimable_stoken > bond_cap:
            return 0, 0, 0, 0

        foregone_amount = chick.bond_amount - mintable_amount * stoken_price
        chicken.chicken_in(chick, claimable_stoken)
        self.chicken_in_counter += 1

        return claimable_stoken, foregone_amount, amm_token_amount, amm_stoken_amount

    def chicken_out(self, chicken, chick, iteration, data):
        """ Chicken  out defines leaving users. User are only allowed to leave if
        the break-even point of the investment is not reached with a predefined
        probability.

        @param chicken: Resources
        @param chick: All users
        @param iteration:
        @param data:
        @return: Total outgoing amount.
        """

        total_chicken_out_amount = 0

        # use actual stoken price instead of weighted average
        # stoken_price = self.get_stoken_price(chicken, data, iteration)
        stoken_price = self.get_stoken_spot_price(chicken)
        max_claimable_stoken = self.get_accumulated_stoken(chick, iteration)
        profit = max_claimable_stoken * stoken_price - chick.bond_amount

        # if break even is not reached and chicken-out proba (10%) is fulfilled
        if profit <= 0 and np.random.binomial(1, self.chicken_out_probability) == 1:
            chicken.chicken_out(chick)
            total_chicken_out_amount += chick.bond_amount
            self.chicken_out_counter += 1

        return total_chicken_out_amount

    def chicken_up(self, chicken, chick, iteration, data):
        """ Chicken-ups are users enabling the access to additional sLQTY tokens.
        User are only allowed to chicken-up if they exceeded the bonding cap and
        only by the outstanding amount of sLQTY tokens.

        @param chicken: The reserve pool object.
        @param chick: The user
        @param iteration: The actual period
        @return: The new claimable and mint-able stoken amount
        """

        # use actual stoken price instead of weighted average
        # stoken_price = self.get_stoken_price(chicken, data, iteration)
        stoken_price = self.get_stoken_spot_price(chicken)
        max_claimable_stoken = self.get_accumulated_stoken(chick, iteration)

        pol_ratio = self.get_pol_ratio(chicken)
        bond_cap = self.get_bond_cap(chick.bond_amount, pol_ratio)

        # Check if the sLQTY cap is exceeded
        if max_claimable_stoken <= bond_cap:
            return 0

        # calculate the maximum amount of LQTY to chicken-up
        top_up_amount = min((max_claimable_stoken - bond_cap) * pol_ratio,
                            chicken.token.balance_of(chick.account))

        # Calculate the claimable_amount as the minimum of max_claimable_amount and
        # the actual top_up_amount. If a chick is not able to chick_up to the total
        # max_claimable_stoken_amount.
        claimable_amount = min(max_claimable_stoken,
                               bond_cap + (top_up_amount / pol_ratio))

        # Check if chicken-up is profitable
        # Profit = (ALL claimable sLQTY * Price) - (Initial investment + additional investment)
        profit = (claimable_amount * stoken_price) - (chick.bond_amount + top_up_amount)
        #target_profit = chick.bond_target_profit * (chick.bond_amount + top_up_amount)

        # Do not chicken-up if the profit is negative or in 80% of the cases.
        if profit <= 0 or np.random.binomial(1, 1 - CHICKEN_UP_PROBABILITY, 1):
            return 0

        # First top up
        chicken.top_up_bond(chick, top_up_amount)
        # Then chicken in
        chicken.chicken_in(chick, claimable_amount)
        self.chicken_up_counter += 1

        return claimable_amount


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
        total_apr = stoken_apr + amm_apr * chicken.amm.get_value_in_token_B_of(chicken.pol_account) \
            / chicken.stoken.total_supply
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

    def get_chicken_in_amm_token_amount(self, foregone_amount, stoken_spot_price):
        amm_token_amount = min(
            foregone_amount * self.chicken_in_amm_share,
            stoken_spot_price * foregone_amount / (stoken_spot_price + 1),
        )
        # print(f"t1: {foregone_amount * self.chicken_in_amm_share:,.2f}")
        # print(f"t2: {stoken_spot_price * foregone_amount / (stoken_spot_price + 1):,.2f}")

        return amm_token_amount

    def get_amm_amounts(self, chicken, foregone_amount):
        stoken_spot_price = self.get_stoken_spot_price(chicken)
        if foregone_amount <= 0 or stoken_spot_price <= 0:
            return

        amm_token_amount = self.get_chicken_in_amm_token_amount(foregone_amount, stoken_spot_price)

        if chicken.amm.token_A_balance() > 0:
            amm_stoken_amount = chicken.amm.get_B_amount_for_liquidity(amm_token_amount)
        else:
            amm_stoken_amount = amm_token_amount / stoken_spot_price
            assert amm_stoken_amount <= amm_token_amount
            assert amm_stoken_amount <= foregone_amount - amm_token_amount

        """
        print("- Divert to AMM")
        print(f"foregone:   {foregone_amount:,.2f}")
        print(f"price:      {stoken_spot_price:,.2f}")
        print(f"token:      {amm_token_amount:,.2f}")
        print(f"stoken:     {amm_stoken_amount:,.2f}")
        print("")
        """

        return amm_token_amount, amm_stoken_amount

    def get_claimable_stoken(self, chicken, chick, iteration, pol_ratio):
        effective_bond_amount = chick.bond_amount * (1 - self.chicken_in_amm_share)
        bond_cap = self.get_bond_cap(effective_bond_amount, pol_ratio)
        claimable_stoken = min(
            effective_bond_amount * self.bond_mint_ratio * (iteration - chick.bond_time),
            bond_cap
        )

        foregone_amount = chick.bond_amount - claimable_stoken
        amm_token_amount, amm_stoken_amount = self.get_amm_amounts(chicken, foregone_amount)

        return claimable_stoken, bond_cap, claimable_stoken, amm_token_amount, amm_stoken_amount

    def divert_to_amm(self, chicken, token_amount, stoken_amount):
        chicken.stoken.mint(chicken.pol_account, stoken_amount)
        token_amount = token_amount * 0.9999  # to avoid rounding issues
        chicken.amm.add_liquidity(chicken.pol_account, token_amount, stoken_amount)

        return

    def chicken_in(self, chicken, chick, data, iteration):
        claimable_stoken, foregone_amount, amm_token_amount, amm_stoken_amount = \
            super().chicken_in(chicken, chick, data, iteration)

        # Redirect part of bond to AMM
        if amm_token_amount > 0:
            self.divert_to_amm(chicken, amm_token_amount, amm_stoken_amount)

        return claimable_stoken, foregone_amount, amm_token_amount, amm_stoken_amount

    """
    TODO:
    def chicken_up(self, chicken, chick, data, iteration):
        claimable_stoken, foregone_amount, amm_token_amount, amm_stoken_amount = \
            super().chicken_up(chicken, chick, data, iteration)

        # Redirect part of bond to AMM
        if amm_token_amount > 0:
            self.divert_to_amm(chicken, amm_token_amount, amm_stoken_amount)

        return claimable_stoken, foregone_amount, amm_token_amount, amm_stoken_amount
    """

    def adjust_liquidity(self, chicken, chicks, amm_average_apr, iteration):
        return

    def buy_stoken(self, chicken, chicks, reserve_ratio):
        # print(f"\n --> Buying sTOKEN")

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

        # print(f"total sTOKEN bought: {total_bought:,.2f}")
        # print(f"total TOKEN sold:    {token_sell_amount - remaining_amount:,.2f}")

        return

    def sell_stoken(self, chicken, chicks, reserve_ratio):
        # print(f"\n --> Selling sTOKEN")

        stoken_sell_amount = min(
            chicken.amm.get_input_B_for_max_slippage(self.max_slippage, 0, 0),
            chicken.amm.get_input_B_amount_from_target_price_A(1 / reserve_ratio)
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

        # print(f"total TOKEN bought: {total_bought:,.2f}")
        # print(f"total sTOKEN sold:  {stoken_sell_amount - remaining_amount:,.2f}")

        return

    def amm_arbitrage(self, chicken, chicks, iteration):
        if chicken.stoken.total_supply == 0:
            return
        reserve_ratio = self.get_reserve_ratio_no_amm(chicken)
        stoken_spot_price = self.get_stoken_spot_price(chicken)
        # print(f"stoken price: {stoken_spot_price:,.2f}")

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
        # print(f"TOKEN from AMM:  {amm_token_amount:,.2f}")
        # print(f"sTOKEN from AMM: {amm_stoken_amount:,.2f}")

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
            if remaining_amount == 0:
                return
            # for chick in self.get_chicks_with_stoken(chicken, chicks, threshold=pol_ratio * 10):
            for chick in self.get_chicks_with_stoken(chicken, chicks, threshold=10):
                # print(f"bal: {chicken.stoken.balance_of(chick.account):,.2f}")
                # print(f"rem: {remaining_amount:,.2f}")
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

    """
    As AMM is out of redemption / backing ratio, we first remove AMM token toll
    With that, along with the backing ratio, we get the total amount of sTOKEN to be minted
    From that amount we subtract the sTOKEN toll, so that the sTOKEN total supply will remain
    and therefore the backing ratio too.
    """

    def get_claimable_stoken(self, chicken, chick, iteration, pol_ratio):
        token_toll = chick.bond_amount * self.chicken_in_amm_share
        effective_bond_amount = chick.bond_amount - token_toll
        bond_cap = self.get_bond_cap(effective_bond_amount, pol_ratio)
        mintable_amount = min(
            # TODO: should we use here total or effective bond amount?
            effective_bond_amount * self.bond_mint_ratio * (iteration - chick.bond_time),
            bond_cap
        )

        # subtract to be minted sTOKEN
        stoken_price = self.get_stoken_spot_price(chicken)
        stoken_toll = token_toll / stoken_price

        # Note: stoken_toll > mintable_token iff pol_ratio / stoken_price > (1 - chicken_in_amm_share) / chicken_in_amm_share
        # In particular if stoken_price > pol_ratio && chicken_in_amm_share < 0.5, it won’t hold
        claimable_stoken = max(mintable_amount - stoken_toll, 0)
        """
        print("\n\n")
        print(f"POL ratio: {pol_ratio:,.2f}")
        print(chick)
        print(f"Bond:              {chick.bond_amount:,.2f}")
        print(f"Effective bond:    {effective_bond_amount:,.2f}")
        print(f"TOKEN toll:        {token_toll:,.2f}")
        print(f"sTOKEN price:      {stoken_price:,.2f}")
        print(f"sTOKEN toll:       {stoken_toll:,.2f}")
        print(f"Cap:               {bond_cap:,.2f}")
        print(f"Mintable pre cap:  {effective_bond_amount * self.bond_mint_ratio * (iteration - chick.bond_time):,.2f}")
        print(f"Mintable:          {mintable_amount:,.2f}")
        print(f"Claimable:         {claimable_stoken:,.2f}")
        print(f"r/p:               {pol_ratio / stoken_price:,.2f}")
        print(f"(1-s)/s:           {(1 - self.chicken_in_amm_share) / self.chicken_in_amm_share:,.2f}")
        """

        return mintable_amount, bond_cap, claimable_stoken, token_toll, stoken_toll

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

    def get_claimable_stoken(self, chicken, chick, iteration, pol_ratio):
        effective_bond_amount = chick.bond_amount * (1 - self.chicken_in_amm_share)
        bond_cap = self.get_bond_cap(effective_bond_amount, pol_ratio)
        claimable_stoken = min(
            effective_bond_amount * self.bond_mint_ratio * (iteration - chick.bond_time),
            bond_cap
        )

        return claimable_stoken, bond_cap, claimable_stoken, 0, 0

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
            # print(f"TOKEN from AMM:  {amm_token_amount:,.2f}")
            # print(f"sTOKEN from AMM: {amm_stoken_amount:,.2f}")
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


class TesterRebonding(TesterIssuanceBondsAMM_2):
    def __init__(self):
        super().__init__()
        self.name = "Bonds with AMM model - approach 2 - with Rebonding"
        self.plot_prefix = '0_5'
        self.plot_file_description = 'bonds_amm_2_rebonding'
        return

    def init(self, chicks):
        BONDERS = 20  # TODO
        for i in range(BONDERS):
            chicks[i].rebonder = True

        return

    def get_bonded_chicks(self, chicks):
        return list(filter(lambda chick: chick.bond_amount > 0 and not chick.rebonder, chicks))

    def get_rebonders(self, chicks):
        return list(filter(lambda chick: chick.bond_amount > 0 and chick.rebonder, chicks))

    def rebond(self, chicken, chicks, data, iteration):
        # If AMM price is lower than redemption price, rebonding is not profitable
        if self.get_stoken_spot_price(chicken) <= self.get_pol_ratio(chicken):
            return 0, 0, 0, 0
        total_chicken_in_amount = 0
        total_chicken_in_foregone = 0
        total_rebonded = 0
        rebonders = self.get_rebonders(chicks)
        # print(f"\n\n-- Rebond")
        # print(f"Rebonds: {len(rebonders)}")
        for chick in rebonders:
            claimable_stoken, new_chicken_in_forgone, amm_token_amount, amm_stoken_amount = \
                self.chicken_in(chicken, chick, iteration, data)
            if claimable_stoken == 0:
                continue
            """
            print("\n \033[31mBalances before\033[0m")
            print(f" - {chicken.token.symbol} balance: {chicken.token.balance_of(chick.account):,.2f}")
            print(f" - {chicken.token.symbol} bonded:  {chick.bond_amount:,.2f}")
            print(f" - {chicken.stoken.symbol} balance: {chicken.stoken.balance_of(chick.account):,.2f}")
            """

            # Redirect part of bond to AMM
            if amm_token_amount > 0:
                self.divert_to_amm(chicken, amm_token_amount, amm_stoken_amount)

            # rebond
            # sell sTOKEN in the AMM
            stoken_swap_amount = min(
                chicken.amm.get_input_B_for_max_slippage(self.max_slippage, 0, 0),
                claimable_stoken,
            )
            bought_token_amount = chicken.amm.swap_B_for_A(chick.account, stoken_swap_amount)
            # bond again
            chicken.bond(chick, bought_token_amount, 0, iteration)
            total_rebonded = total_rebonded + bought_token_amount

            """
            print(f"Sold sTOKEN:  {stoken_swap_amount:,.2f}")
            print(f"Bought TOKEN: {bought_token_amount:,.2f}")
            print("\n \033[32mBalances after\033[0m")
            print(f" - {chicken.token.symbol} balance: {chicken.token.balance_of(chick.account):,.2f}")
            print(f" - {chicken.token.symbol} bonded:  {chick.bond_amount:,.2f}")
            print(f" - {chicken.stoken.symbol} balance: {chicken.stoken.balance_of(chick.account):,.2f}")
            """

        # TODO: rebond after chicken up

        total_chicken_out_amount = 0

        return total_chicken_in_amount, total_chicken_in_foregone, total_chicken_out_amount, total_rebonded

    def update_chicken(self, chicken, chicks, data, iteration):
        # rebond
        _, rebond_foregone, _, total_rebonded = self.rebond(chicken, chicks, data, iteration)
        # if total_rebonded > 0:
        #    exit(1)
        #total_chicken_in_foregone = total_chicken_in_foregone + rebond_foregone

        super().update_chicken(chicken, chicks, data, iteration)

        return
