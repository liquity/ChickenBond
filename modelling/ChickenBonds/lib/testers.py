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

    def get_fair_price(self, chicken):
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

    def get_pol_ratio(self, chicken):
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


class TesterSimpleToll(TesterInterface):
    def __init__(self):
        super().__init__()
        self.name = "Simple toll model"
        self.plot_prefix = '0_0'
        self.plot_file_description = 'simple_toll'

        self.price_max_value = 2 # for plots, for a better scaling

        self.pol_ratio = 1
        self.initial_price = INITIAL_PRICE
        self.twap_period = TWAP_PERIOD
        self.price_premium = PRICE_PREMIUM
        self.price_volatility = PRICE_VOLATILITY

        self.external_yield = EXTERNAL_YIELD

        self.bond_mint_ratio = BOND_STOKEN_ISSUANCE_RATE
        self.bond_probability = BOND_PROBABILITY
        self.chicken_in_gamma_shape = CHICKEN_IN_GAMMA[0]
        self.chicken_in_gamma_scale = CHICKEN_IN_GAMMA[1]
        self.chicken_out_probability = CHICKEN_OUT_PROBABILITY

        self.rebonders = NUM_REBONDERS
        self.lps = NUM_LPS

        self.max_slippage = MAX_SLIPPAGE
        self.amm_arbitrage_divergence = AMM_ARBITRAGE_DIVERGENCE
        self.amm_yield = AMM_YIELD

        self.redemption_arbitrage_divergence = REDEMPTION_ARBITRAGE_DIVERGENCE
        return

    def init(self, chicks):
        for i in range(self.rebonders):
            chicks[i].rebonder = True
        for i in range(self.rebonders, self.rebonders + self.lps):
            chicks[i].lp = True

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

    """
    def get_bonded_chicks(self, chicks):
        return list(filter(lambda chick: chick.bond_amount > 0 and not chick.rebonder, chicks))

    def get_rebonders(self, chicks):
        return list(filter(lambda chick: chick.bond_amount > 0 and chick.rebonder, chicks))
    """

    def get_bond_cap(self, bond_amount, pol_ratio):
        if pol_ratio == 0:
            return 999999999
        return bond_amount / pol_ratio

    def get_natural_rate(self, previous_natural_rate, iteration):
        np.random.seed(2021 * iteration)
        shock_natural_rate = np.random.normal(0, SD_NATURAL_RATE)
        new_natural_rate = previous_natural_rate * (1 + shock_natural_rate)
        # print(f"previous natural rate: {previous_natural_rate:.3%}")
        # print(f"new natural rate:      {new_natural_rate:.3%}")

        return new_natural_rate

    def get_fair_price(self, chicken):
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
        premium_mapper = {"normal_dist": np.random.normal(mu, sigma, 1)[0] / stoken_supply,
                          "perpetuity": (chicken.coop_token_balance() * EXTERNAL_YIELD) ** (1 / TIME_UNITS_PER_YEAR),
                          "coop_balance": (chicken.coop_token_balance() + (self.amm_yield/self.external_yield) * chicken.amm.get_value_in_token_A()) / stoken_supply,
                          }

        # Different methods to include volatility in the price.
        volatility_mapper = {"None": 0,
                             "bounded": min(np.random.normal(VOLA_MU, VOLA_SIGMA, 1), base_amount / stoken_supply),
                             "unbounded": np.random.normal(VOLA_MU, VOLA_SIGMA, 1),
                             }

        total_price = (base_amount / stoken_supply) \
                      + premium_mapper.get(self.price_premium, 0) \
                      + volatility_mapper.get(self.price_volatility, 0)

        return total_price

    def get_stoken_spot_price(self, chicken):
        return self.get_fair_price(chicken)

    def get_stoken_twap(self, data, iteration):
        if iteration <= self.twap_period:
            return self.initial_price
        # print(data[iteration - self.twap_period : iteration]["stoken_price"])
        # print(f"average: {data[iteration - self.twap_period : iteration].mean()['stoken_price']:,.2f}")
        return data[iteration - self.twap_period: iteration].mean()["stoken_price"]

    def get_stoken_price(self, chicken, data, iteration):
        return self.get_stoken_twap(data, iteration)

    def get_pol_ratio(self, chicken):
        #return chicken.get_pol_ratio_no_amm()
        return self.pol_ratio

    def get_reserve_ratio(self, chicken):
        return chicken.get_reserve_ratio_no_amm()

    def get_stoken_apr_from_price(self, chicken, stoken_price):
        base_amount = chicken.coop_token_balance() + chicken.pol_token_balance()
        generated_yield = base_amount * self.external_yield
        stoken_supply = chicken.stoken.total_supply
        if stoken_supply == 0 or stoken_price == 0:
            return 0

        return generated_yield / (stoken_supply * stoken_price)

    def get_stoken_apr_with_amm(self, chicken, stoken_apr, amm_apr):
        if chicken.stoken.total_supply == 0:
            return stoken_apr
        total_apr = stoken_apr + amm_apr * chicken.amm.get_value_in_token_B_of(chicken.pol_account) \
            / chicken.stoken.total_supply
        return total_apr

    def get_stoken_apr_spot(self, chicken):
        stoken_spot_price = self.get_stoken_spot_price(chicken)
        base_apr = self.get_stoken_apr_from_price(chicken, stoken_spot_price)
        return self.get_stoken_apr_with_amm(chicken, base_apr, chicken.amm_iteration_apr)

    def get_stoken_apr_twap(self, chicken, data, iteration):
        stoken_twap = self.get_stoken_twap(data, iteration)
        base_apr = self.get_stoken_apr_from_price(chicken, stoken_twap)
        return self.get_stoken_apr_with_amm(chicken, base_apr, chicken.amm_average_apr)

    def get_stoken_apr(self, chicken, data, iteration):
        return self.get_stoken_apr_twap(chicken, data, iteration)

    # https://www.desmos.com/calculator/taphbjrugg
    # See also: https://homepage.divms.uiowa.edu/~mbognar/applets/gamma.html
    def get_chicken_in_profit_percentage(self):
        return np.random.gamma(self.chicken_in_gamma_shape, self.chicken_in_gamma_scale, 1)[0]

    def get_yield_amount(self, base_amount, yield_percentage):
        return base_amount * ((1 + yield_percentage) ** (1 / TIME_UNITS_PER_YEAR) - 1)

    def distribute_yield(self, chicken, chicks, iteration):
        initial_pol_balance = chicken.pol_token_balance()

        # Reserve generated yield
        generated_yield = self.get_yield_amount(chicken.reserve_token_balance(), self.external_yield)

        chicken.token.mint(chicken.pol_account, generated_yield)

        # AMM generated yield
        generated_yield = self.get_yield_amount(chicken.amm.get_value_in_token_A(), self.amm_yield)

        chicken.token.mint(chicken.pol_account, generated_yield)

        final_pol_balance = chicken.pol_token_balance()
        if initial_pol_balance > 0 and chicken.stoken.total_supply > 0:
            self.pol_ratio = self.pol_ratio * final_pol_balance / initial_pol_balance

        return

    def bond(self, chicken, chicks, iteration):
        np.random.seed(2022 * iteration)
        np.random.shuffle(chicks)
        not_bonded_chicks = self.get_available_for_bonding_chicks(chicken, chicks)
        not_bonded_chicks_len = len(not_bonded_chicks)
        num_new_bonds = np.random.binomial(not_bonded_chicks_len, self.bond_probability)
        if iteration == 0:
            num_new_bonds = BOOTSTRAP_NUM_BONDS
        # print(f"available: {not_bonded_chicks_len:,.2f}")
        # print(f"bonding:   {num_new_bonds:,.2f}")
        for chick in not_bonded_chicks[:num_new_bonds]:
            amount = min(
                chicken.token.balance_of(chick.account),
                np.random.randint(BOND_AMOUNT[0], BOND_AMOUNT[1], 1)[0]
            )
            if amount == 0:
                continue
            target_profit = self.get_chicken_in_profit_percentage()
            # print(f"amount: {amount:,.2f}")
            # print(f"profit: {target_profit:.3%}")
            chicken.bond(chick, amount, target_profit, iteration)
        return

    def get_pol_ratio_update_chicken(self, chicken, chick, iteration):
        assert iteration >= chick.bond_time
        pol_ratio = self.get_pol_ratio(chicken)
        assert pol_ratio == 0 or pol_ratio >= 1
        if pol_ratio == 0:
            pol_ratio = 1
        return pol_ratio

    def update_chicken(self, chicken, chicks, data, iteration):
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

        bonded_chicks = self.get_bonded_chicks(chicks)
        #print(f"Bonded Chicks ini: {len(bonded_chicks)}")

        # ----------- Chicken-out --------------------
        for chick in bonded_chicks:
            pol_ratio = self.get_pol_ratio_update_chicken(chicken, chick, iteration)

            # Check if chicken-out conditions are met and eventually chicken-out
            self.chicken_out(chicken, chick, iteration, data)

        bonded_chicks = self.get_bonded_chicks(chicks)
        #print(f"Bonded Chicks: {len(bonded_chicks)}")

        # ----------- Chicken-in --------------------
        for chick in bonded_chicks:
            pol_ratio = self.get_pol_ratio_update_chicken(chicken, chick, iteration)

            # Check if chicken-in conditions are met and eventually chicken-in
            self.chicken_in(chicken, chick, iteration, data)

        bonded_chicks = self.get_bonded_chicks(chicks)
        #print(f"Bonded Chicks fin: {len(bonded_chicks)}")

        print("Out:", self.chicken_out_counter)
        print("In:", self.chicken_in_counter)
        print("Locked:", self.chicken_up_locked)
        self.chicken_up_locked = 0

        return

    def is_bootstrap_chicken_out(self, chick, iteration):
        return iteration <= BOOTSTRAP_ITERATION and chick.bond_time == 0

    def get_claimable_amount(self, chicken, chick, iteration):
        pol_ratio = self.get_pol_ratio(chicken)
        bond_cap = self.get_bond_cap(chick.bond_amount, pol_ratio)
        bond_duration = iteration - chick.bond_time
        claimable_amount =  bond_cap * bond_duration / (bond_duration + 1)
        assert claimable_amount < bond_cap
        return claimable_amount, bond_cap

    def chicken_out(self, chicken, chick, iteration, data):
        """ Chicken  out defines leaving users. User are only allowed to leave if
        the break-even point of the investment is not reached with a predefined
        probability.

        @param chicken: Resources
        @param chick: All users
        @param iteration:
        @param data:
        """

        # use actual stoken price instead of weighted average
        # stoken_price = self.get_stoken_price(chicken, data, iteration)
        stoken_price = self.get_stoken_spot_price(chicken)
        claimable_amount, _ = self.get_claimable_amount(chicken, chick, iteration)
        profit = claimable_amount * stoken_price - chick.bond_amount

        # skip chicken out for bootstrappers
        if self.is_bootstrap_chicken_out(chick, iteration):
            return

        # if break even is reached or chicken-out proba (10%) is not fulfilled
        if profit > 0 or np.random.binomial(1, self.chicken_out_probability) == 0:
            return

        chicken.chicken_out(chick)
        self.chicken_out_counter += 1
        return

    def is_bootstrap_chicken_in(self, chick, iteration):
        return iteration == BOOTSTRAP_ITERATION and chick.bond_time == 0

    def get_amm_amounts(self, chicken, bond_cap, claimable_amount):
        pol_ratio = self.get_pol_ratio(chicken)

        amm_stoken_amount = bond_cap - claimable_amount
        # Forget about LQTY/ETH price for now
        amm_token_amount = amm_stoken_amount * pol_ratio / 2
        amm_coll_amount = amm_token_amount

        """
        print("- Divert to AMM")
        print(f"token:      {amm_token_amount:,.2f}")
        print(f"2 x token:  {2*amm_token_amount:,.2f}")
        print(f"stoken:     {amm_stoken_amount:,.2f}")
        print("")
        """

        return amm_token_amount, amm_coll_amount

    def divert_to_amm(self, chicken, token_amount, coll_amount):
        # Simulate a swap LQTY -> ETH
        # “magically” mint ETH
        chicken.coll_token.mint(chicken.pol_account, coll_amount+1)
        # “magically” burn LQTY
        chicken.token.burn(chicken.pol_account, token_amount)

        # Add liquidity
        chicken.amm.add_liquidity(chicken.pol_account, token_amount, coll_amount)

        return

    def get_rebond_time(self, chicken):
        from scipy.special import lambertw
        stoken_spot_price = self.get_stoken_spot_price(chicken)
        pol_ratio = self.get_pol_ratio(chicken)
        w = lambertw(math.exp(1) * pol_ratio / stoken_spot_price).real
        rebond_time = w / (1 - w)
        """
        print("")
        print(f"stoken price: {stoken_spot_price}")
        print(f"pol_ratio:    {pol_ratio}")
        print(f"lambda:       {stoken_spot_price/pol_ratio}")
        print(f"lambertW:     {w}")
        print(f"\033[34mrebond_time:  {rebond_time:,.2f}\033[0m")
        """

        return rebond_time.real

    def rebond(self, chicken, chick, claimable_amount, iteration):
        # sell sTOKEN in the AMM
        chicken.stoken_amm.set_price_B(self.get_stoken_spot_price(chicken))
        # we use all balance in case a previous rebond was capped due to low liquidity
        stoken_balance = chicken.stoken.balance_of(chick.account)
        assert stoken_balance >= claimable_amount
        stoken_swap_amount = min(
            chicken.stoken_amm.get_input_B_for_max_slippage(self.max_slippage, 0, 0),
            stoken_balance,
        )
        bought_token_amount = chicken.stoken_amm.swap_B_for_A(chick.account, stoken_swap_amount)
        # bond again
        chicken.bond(chick, bought_token_amount, 0, iteration)

        """
        if chick.account == 'chick_02':
            print("")
            print("-- Rebond")
            print(f"max swap:     {chicken.stoken_amm.get_input_B_for_max_slippage(self.max_slippage, 0, 0):,.2f}")
            print(f"claimable:    {claimable_amount:,.2f}")
            print(f"Sold sTOKEN:  {stoken_swap_amount:,.2f}")
            print(f"Bought TOKEN: {bought_token_amount:,.2f}")
            print("\n \033[32mBalances after\033[0m")
            print(f" - {chicken.token.symbol} balance: {chicken.token.balance_of(chick.account):,.2f}")
            print(f" - {chicken.token.symbol} bonded:  {chick.bond_amount:,.2f}")
            print(f" - {chicken.stoken.symbol} balance: {chicken.stoken.balance_of(chick.account):,.2f}")
        """

        return

    def chicken_in(self, chicken, chick, iteration, data):
        """ User may chicken-in if the have already exceeded the break-even
        point of their investment and not yet exceeded the bonding cap.

        @param chicken: The resources.
        @param chick: The user
        @param iteration: The iteration step
        @param data: Logging data
        """

        #if iteration < BOOTSTRAP_ITERATION:
        #    return 0, 0, 0

        claimable_amount, bond_cap = self.get_claimable_amount(chicken, chick, iteration)
        if claimable_amount == 0:
            return
        amm_token_amount, amm_coll_amount = self.get_amm_amounts(chicken, bond_cap, claimable_amount)

        # use actual stoken price instead of weighted average
        stoken_price = self.get_stoken_spot_price(chicken)
        profit = claimable_amount * stoken_price - chick.bond_amount
        target_profit = chick.bond_target_profit * chick.bond_amount

        """
        if chick.account == 'chick_02':
            print("")
            print(chick)
            print("-- Chicken in")
            print(f"claimable_amount: {claimable_amount:,.2f}")
            print(f"bond cap:         {bond_cap:,.2f}")
            print(f"bond amount:      {chick.bond_amount:,.2f}")
            print(f"bond time:        {chick.bond_time}")
            print(f"amm amount:       {amm_token_amount:,.2f}")
            print(f"\033[34mprice:            {stoken_price:,.2f}\033[0m")
            print(f"profit:           {profit:,.2f}")
            print(f"target profit:    {target_profit:,.2f}")
            print(f"pol ratio:        {self.get_pol_ratio(chicken):,.2f}")
            print(f"new pol amount:   {chick.bond_amount - 2*amm_token_amount:,.2f}")
            print(f"new ratio:        {(chick.bond_amount - 2*amm_token_amount) / claimable_amount:,.2f}")
        """

        if chick.rebonder:
            # If it’s a rebonder and the optimal point hasn’t been reached yet
            rebond_time = self.get_rebond_time(chicken)
            if iteration - chick.bond_time < rebond_time:
                #print(f"rebond_time: {rebond_time:,.2f}")
                #print(f"time gone:   {iteration - chick.bond_time:,.2f}")
                return
        else:
            # If the chicks profit are below their target_profit,
            # do neither chicken-in nor chicken-up.
            if profit <= target_profit:
                self.chicken_up_locked += 1
                # except for bootstrappers
                if not self.is_bootstrap_chicken_in(chick, iteration):
                    return

        #print("\n --> Chickening in!")
        chicken.chicken_in(chick, claimable_amount)
        self.chicken_in_counter += 1

        # Redirect part of bond to AMM
        if amm_token_amount > 0:
            #print("\n --> Diverting!")
            self.divert_to_amm(chicken, amm_token_amount, amm_coll_amount)

        if chick.rebonder:
            # Rebond
            #print("\n --> Rebonding!")
            self.rebond(chicken, chick, claimable_amount, iteration)
        elif chick.lp:
            # Provide liquidity to TOKEN/sTOKEN pool
            chicken.stoken_amm.add_liquidity_single_B(chick.account, claimable_amount, 0) # TODO


        return

    def adjust_liquidity(self, chicken, chicks, amm_average_apr, iteration):
        return

    """
    def buy_stoken(self, chicken, chicks, reserve_ratio):
        # print(f"\n --> Buying sTOKEN")

        token_sell_amount = min(
            chicken.stoken_amm.get_input_A_for_max_slippage(self.max_slippage, 0, 0),
            chicken.stoken_amm.get_input_A_amount_from_target_price_B(reserve_ratio)
        )

        total_bought = 0
        remaining_amount = token_sell_amount
        for chick in chicks:
            # swap
            swap_amount = min(remaining_amount, chicken.token.balance_of(chick.account))
            if swap_amount < 0.1:
                continue
            bought_stoken_amount = chicken.stoken_amm.swap_A_for_B(chick.account, swap_amount)

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
            chicken.stoken_amm.get_input_B_for_max_slippage(self.max_slippage, 0, 0),
            chicken.stoken_amm.get_input_B_amount_from_target_price_A(1 / reserve_ratio)
        )

        total_bought = 0
        remaining_amount = stoken_sell_amount
        for chick in chicks:
            # swap
            swap_amount = min(remaining_amount, chicken.stoken.balance_of(chick.account))
            if swap_amount < 0.1:
                continue
            bought_token_amount = chicken.stoken_amm.swap_B_for_A(chick.account, swap_amount)

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

        fair_price = self.get_fair_price(chicken)
        stoken_spot_price = self.get_stoken_spot_price(chicken)
        # print(f"fair price:   {fair_price:,.2f}")
        # print(f"stoken price: {stoken_spot_price:,.2f}")

        # if there’s more than 5% divergence, balance between AMM and reserve ratio
        if fair_price < stoken_spot_price * (1 - self.amm_arbitrage_divergence):
            return self.sell_stoken(chicken, chicks, fair_price)
        elif fair_price > stoken_spot_price * (1 + self.amm_arbitrage_divergence):
            return self.buy_stoken(chicken, chicks, fair_price)
    """

    """
    # Only POL, without AMM
    def redeem(self, chicken, chick, stoken_amount, pol_ratio):
        token_amount = stoken_amount * pol_ratio

        pol_token_balance = chicken.pol_token_balance()

        ""#"
        print("")
        print("---")
        print(chick)
        print(f"TOKEN bal before:  {chicken.token.balance_of(chick.account):,.2f}")
        print(f"sTOKEN bal before: {chicken.stoken.balance_of(chick.account):,.2f}")
        print("---")
        print(f"stoken_amount:     {stoken_amount:,.2f}")
        print(f"token_amount:      {token_amount:,.2f}")
        print(f"pol_token_balance: {pol_token_balance:,.2f}")
        ""#"

        # burn sTOKEN
        chicken.stoken.burn(chick.account, stoken_amount)

        # transfer TOKEN
        chicken.token.transfer(chicken.pol_account, chick.account, token_amount)

        # swap TOKEN for sTOKEN
        bought_stoken_amount = chicken.stoken_amm.swap_A_for_B(chick.account, token_amount)

        redemption_result = bought_stoken_amount

        ""#"
        print(f"redemption result: {redemption_result:,.2f}")
        print("---")
        print(f"TOKEN bal after:   {chicken.token.balance_of(chick.account):,.2f}")
        print(f"sTOKEN bal after:  {chicken.stoken.balance_of(chick.account):,.2f}")
        ""#"

        assert stoken_amount < redemption_result
        return redemption_result

    def redemption_arbitrage(self, chicken, chicks, iteration):
        if chicken.stoken.total_supply == 0:
            return
        # redemption price
        pol_ratio = self.get_pol_ratio(chicken)
        stoken_spot_price = self.get_stoken_spot_price(chicken)

        # if there’s more than 5% divergence, balance between redemption and sTOKEN prices
        ""#"
        print(f"\nPOL ratio:       {pol_ratio:,.2f}")
        print(f"Price:           {stoken_spot_price:,.2f}")
        print(f"Price threshold: {stoken_spot_price * (1 + self.redemption_arbitrage_divergence):,.2f}")
        ""#"
        if pol_ratio > stoken_spot_price * (1 + self.redemption_arbitrage_divergence):
            token_swap_amount = min(
                chicken.stoken_amm.get_input_A_for_max_slippage(self.max_slippage, 0, 0),
                chicken.stoken_amm.get_input_A_amount_from_target_price_B(pol_ratio)
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
        return
    """

