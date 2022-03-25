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
        self.chicken_in_locked = 0

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

    def get_bonding_apr_spot(self, chicken):
        pass

    def get_bonding_apr_twap(self, chicken, data, iteration):
        pass

    def get_stoken_apr_spot(self, chicken, data, iteration):
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

class TesterSimpleToll(TesterInterface):
    def __init__(self):
        super().__init__()
        self.name = "Simple toll model"
        self.plot_prefix = '0_0'
        self.plot_file_description = 'simple_toll'

        self.price_max_value = 2
        self.apr_min_value = -10
        self.apr_max_value = 100
        self.time_max_value = 40

        self.initial_price = INITIAL_PRICE
        self.twap_period = TWAP_PERIOD
        self.price_premium = PRICE_PREMIUM
        self.price_volatility = PRICE_VOLATILITY

        self.external_yield = EXTERNAL_YIELD

        self.bond_mint_ratio = BOND_STOKEN_ISSUANCE_RATE
        self.chicken_in_gamma_shape = CHICKEN_IN_GAMMA[0]
        self.chicken_in_gamma_scale = CHICKEN_IN_GAMMA[1]
        self.chicken_out_probability = CHICKEN_OUT_PROBABILITY
        self.chicken_in_amm_tax = CHICKEN_IN_AMM_TAX

        self.rebonders = NUM_REBONDERS
        self.lps = NUM_LPS

        self.max_slippage = MAX_SLIPPAGE
        self.amm_yield = AMM_YIELD

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
            filter(lambda chick: chick.bond_amount == 0 and chicken.token.balance_of(chick.account) > 0, chicks))

    def get_chicks_with_stoken(self, chicken, chicks, threshold=0):
        return list(filter(lambda chick: chicken.stoken.balance_of(chick.account) > threshold, chicks))

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

    def get_premium(self, chicken):
        stoken_supply = chicken.stoken.total_supply
        if stoken_supply == 0:
            return 0

        base_amount = chicken.pol_token_balance()

        mu = base_amount * PREMIUM_MU
        sigma = mu * PREMIUM_SIGMA

        # Different methods to estimate the premium of sLQTY tokens.
        premium_mapper = {"normal_dist": np.random.normal(mu, sigma, 1)[0] / stoken_supply,
                          "perpetuity": (chicken.coop_token_balance() * EXTERNAL_YIELD) ** (1 / TIME_UNITS_PER_YEAR),
                          "coop_balance": chicken.coop_token_balance() / stoken_supply,
                          "full_balance": (chicken.coop_token_balance() + (self.amm_yield/self.external_yield) * chicken.amm.get_value_in_token_A()) / stoken_supply,
                          }

        return premium_mapper.get(self.price_premium, 0)

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

        # Different methods to include volatility in the price.
        volatility_mapper = {"None": 0,
                             "bounded": min(np.random.normal(VOLA_MU, VOLA_SIGMA, 1), base_amount / stoken_supply),
                             "unbounded": np.random.normal(VOLA_MU, VOLA_SIGMA, 1),
                             }

        total_price = base_amount / stoken_supply \
                      + self.get_premium(chicken) \
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
        return chicken.get_pol_ratio_no_amm()

    def get_reserve_ratio(self, chicken):
        return chicken.get_reserve_ratio_no_amm()

    def get_optimal_apr_chicken_in_time(self, chicken):
        """
        p = self.get_premium(chicken)
        r = self.get_pol_ratio(chicken)
        if p == 0:
            return 0
        return (r + math.sqrt(r * (r+p))) / p
        """
        m = self.get_stoken_spot_price(chicken)
        r = self.get_pol_ratio(chicken)
        if m <= r:
            return ITERATIONS

        chicken_in_time = (r + math.sqrt(r * m)) / (m - r)

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
        m = self.get_stoken_spot_price(chicken)
        r = self.get_pol_ratio(chicken)
        if m <= r:
            return 0
        # optimal_time
        t = self.get_optimal_apr_chicken_in_time(chicken)
        apr = (m/r * t / (t+1) - 1) * TIME_UNITS_PER_YEAR / t
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

    def get_stoken_apr_spot(self, chicken, data, iteration):
        APR_SPAN = 30
        if iteration == 0:
            return 0

        span = min(APR_SPAN, iteration)
        previous_spot_price = data["stoken_price"][iteration-span]
        if previous_spot_price == 0:
            return 0
        current_spot_price = self.get_stoken_spot_price(chicken)
        #print(f"previous_spot_price: {previous_spot_price:,.2f}")
        #print(f"current_spot_price:  {current_spot_price:,.2f}")

        return (current_spot_price / previous_spot_price - 1) * TIME_UNITS_PER_YEAR / span

    def get_stoken_apr_twap(self, chicken, data, iteration):
        return self.get_twap_metric(chicken, data, iteration, "stoken_apr")

    def get_stoken_apr(self, chicken, data, iteration):
        return self.get_stoken_apr_twap(chicken, data, iteration)

    # https://www.desmos.com/calculator/taphbjrugg
    # See also: https://homepage.divms.uiowa.edu/~mbognar/applets/gamma.html
    def get_chicken_in_profit_percentage(self):
        return np.random.gamma(self.chicken_in_gamma_shape, self.chicken_in_gamma_scale, 1)[0]

    def get_yield_amount(self, base_amount, yield_percentage):
        return base_amount * ((1 + yield_percentage) ** (1 / TIME_UNITS_PER_YEAR) - 1)

    def distribute_yield(self, chicken, chicks, iteration):
        # Reserve generated yield
        generated_yield = self.get_yield_amount(chicken.reserve_token_balance(), self.external_yield)

        chicken.token.mint(chicken.pol_account, generated_yield)

        # AMM generated yield
        generated_yield = self.get_yield_amount(chicken.amm.get_value_in_token_A(), self.amm_yield)

        chicken.token.mint(chicken.pol_account, generated_yield)

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
        not_bonded_chicks_len = len(not_bonded_chicks)
        num_new_bonds = np.random.binomial(not_bonded_chicks_len, self.get_bond_probability(chicken))
        if iteration == 0:
            num_new_bonds = BOOTSTRAP_NUM_BONDS
        #print(f"available: {not_bonded_chicks_len:,.2f}")
        #print(f"bonding:   {num_new_bonds:,.2f}")
        for chick in not_bonded_chicks[:num_new_bonds]:
            amount = min(
                chicken.token.balance_of(chick.account),
                np.random.randint(BOND_AMOUNT[0], BOND_AMOUNT[1], 1)[0]
            )
            if amount == 0:
                continue
            target_profit = self.get_chicken_in_profit_percentage()
            """
            print("\n \033[33m--> Bonding!\033[0m")
            print(chick)
            print(f"amount: {amount:,.2f}")
            print(f"profit: {target_profit:.3%}")
            """
            chicken.bond(chick, amount, target_profit, iteration)
        return

    def get_pol_ratio_update_chicken(self, chicken, chick, iteration):
        assert iteration >= chick.bond_time
        pol_ratio = self.get_pol_ratio(chicken)
        #print(f"backing ratio: {pol_ratio}")
        assert pol_ratio == 0 or pol_ratio - 1 > -0.00001
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

        # ----------- Chicken-out --------------------
        bonded_chicks = self.get_bonded_chicks(chicks)
        #print(f"Bonded Chicks ini: {len(bonded_chicks)}")

        for chick in bonded_chicks:
            pol_ratio = self.get_pol_ratio_update_chicken(chicken, chick, iteration)

            # Check if chicken-out conditions are met and eventually chicken-out
            self.chicken_out(chicken, chick, iteration, data)

        # ----------- Chicken-in --------------------
        # LPs first
        bonded_chicks = self.get_bonded_chicks_lps(chicks)
        #print(f"Bonded Chicks: {len(bonded_chicks)}")

        for chick in bonded_chicks:
            pol_ratio = self.get_pol_ratio_update_chicken(chicken, chick, iteration)

            # Check if chicken-in conditions are met and eventually chicken-in
            self.chicken_in(chicken, chick, iteration, data)

        # Non LPs afterwards
        bonded_chicks = self.get_bonded_chicks_non_lps(chicks)
        #print(f"Bonded Chicks: {len(bonded_chicks)}")

        for chick in bonded_chicks:
            pol_ratio = self.get_pol_ratio_update_chicken(chicken, chick, iteration)

            # Check if chicken-in conditions are met and eventually chicken-in
            self.chicken_in(chicken, chick, iteration, data)

        #bonded_chicks = self.get_bonded_chicks(chicks)
        #print(f"Bonded Chicks fin: {len(bonded_chicks)}")

        """
        print("Out:", self.chicken_out_counter)
        print("In:", self.chicken_in_counter)
        print("Locked:", self.chicken_in_locked)
        """
        self.chicken_in_locked = 0

        return

    def is_bootstrap_chicken_out(self, chick, iteration):
        return iteration <= BOOTSTRAP_ITERATION and chick.bond_time == 0

    def get_claimable_amount(self, chicken, chick, iteration):
        pol_ratio = self.get_pol_ratio(chicken)
        bond_cap = self.get_bond_cap(chick.bond_amount, pol_ratio)
        bond_duration = iteration - chick.bond_time
        claimable_amount =  bond_cap * bond_duration / (bond_duration + 1)
        """
        print("")
        print(f"pol_ratio:        {pol_ratio}")
        print(f"bond_cap:         {bond_cap}")
        print(f"bond_amount:      {chick.bond_amount}")
        print(f"bond_duration:    {bond_duration}")
        print(f"T factor:         {bond_duration / (bond_duration + 1)}")
        print(f"claimable_amount: {claimable_amount}")
        """
        assert claimable_amount < bond_cap or claimable_amount == 0
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

        #print("\n \033[33m--> Chickening out!\033[0m")
        #print(chick)

        chicken.chicken_out(chick)
        self.chicken_out_counter += 1

        return

    def is_bootstrap_chicken_in(self, chick, iteration):
        return iteration == BOOTSTRAP_ITERATION and chick.bond_time == 0

    def get_amm_amounts(self, chicken, bond_cap, claimable_amount):
        pol_ratio = self.get_pol_ratio(chicken)

        amm_stoken_amount = bond_cap - claimable_amount
        # Forget about LQTY/ETH price for now
        amm_token_amount = amm_stoken_amount * pol_ratio / 2 * (1 - self.chicken_in_amm_tax)
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

    def tax_and_chicken_in(self, chicken, chick, claimable_amount):
        # Compute tax and deduct it from bond
        tax_amount = chick.bond_amount * self.chicken_in_amm_tax
        chick.bond_amount = chick.bond_amount - tax_amount

        # Transfer tax amount
        chicken.token.transfer(chicken.coop_account, chicken.stoken_amm.pool_account, tax_amount)
        # Account for extra AMM revenue
        chicken.stoken_amm.add_rewards(tax_amount, 0)

        # Reduce claimable amount proportionally
        claimable_amount = claimable_amount * (1 - self.chicken_in_amm_tax)
        # Chicken in
        chicken.chicken_in(chick, claimable_amount)

        return claimable_amount

    def get_rebond_time(self, chicken):
        from scipy.special import lambertw
        stoken_spot_price = self.get_stoken_spot_price(chicken)
        pol_ratio = self.get_pol_ratio(chicken)
        if stoken_spot_price == 0 or pol_ratio >= stoken_spot_price:
            #print(f"stoken price:     {stoken_spot_price}")
            #print(f"redemption price: {pol_ratio}")
            return ITERATIONS

        w = lambertw(math.exp(1) * pol_ratio / stoken_spot_price).real
        rebond_time = w / (1 - w)
        """
        print("")
        print(f"stoken price:     {stoken_spot_price}")
        print(f"redemption price: {pol_ratio}")
        print(f"lambda:           {stoken_spot_price/pol_ratio}")
        print(f"lambertW:         {w}")
        print(f"\033[34mrebond_time:      {rebond_time:,.2f}\033[0m")
        """

        return min(rebond_time.real, ITERATIONS)

    def rebond(self, chicken, chick, claimable_amount, iteration):
        # If it’s a rebonder and the optimal point hasn’t been reached yet
        rebond_time = self.get_rebond_time(chicken)
        if iteration - chick.bond_time < rebond_time:
            #print(f"rebond_time: {rebond_time:,.2f}")
            #print(f"time gone:   {iteration - chick.bond_time:,.2f}")
            return 0

        #print("\n --> Chickening in!")
        claimable_amount = self.tax_and_chicken_in(chicken, chick, claimable_amount)

        # sell sTOKEN in the AMM
        chicken.stoken_amm.set_price_B(self.get_stoken_spot_price(chicken))
        # we use all balance in case a previous rebond was capped due to low liquidity
        stoken_balance = chicken.stoken.balance_of(chick.account)
        assert stoken_balance >= claimable_amount
        max_swap_amount = chicken.stoken_amm.get_input_B_for_max_slippage(self.max_slippage, 0, 0)
        stoken_swap_amount = min(
            max_swap_amount,
            stoken_balance,
        )
        #print("Rebond -> sell sLQTY")
        bought_token_amount = chicken.stoken_amm.swap_B_for_A(chick.account, stoken_swap_amount)
        if bought_token_amount < 1e-3:
            #print(f"max swap:     {max_swap_amount:,.2f}")
            return 1
        # bond again
        chicken.bond(chick, bought_token_amount, 0, iteration)

        """
        #if chick.account == 'chick_01':
        if max_swap_amount < stoken_balance:
            print("")
            print("-- Rebond")
            print(chick)
            print(f"max swap:     {max_swap_amount:,.2f}")
            print(f"claimable:    {claimable_amount:,.2f}")
            print(f"balance:      {stoken_balance:,.2f}")
            print(f"Sold sTOKEN:  {stoken_swap_amount:,.2f}")
            print(f"Bought TOKEN: {bought_token_amount:,.2f}")
            print("\n \033[32mBalances after\033[0m")
            print(f" - {chicken.token.symbol} balance: {chicken.token.balance_of(chick.account):,.2f}")
            print(f" - {chicken.token.symbol} bonded:  {chick.bond_amount:,.2f}")
            print(f" - {chicken.stoken.symbol} balance: {chicken.stoken.balance_of(chick.account):,.2f}")
        """

        assert chick.bond_amount > 0.1

        return 1

    def lp_chicken_in(self, chicken, chick, claimable_amount, iteration):
        # If it’s an LP and the optimal point hasn’t been reached yet
        chicken_in_time = self.get_optimal_apr_chicken_in_time(chicken)
        if iteration - chick.bond_time < chicken_in_time:
            #print(f"chicken_in_time: {chicken_in_time:,.2f}")
            #print(f"time gone:       {iteration - chick.bond_time:,.2f}")
            return 0

        #print("\n --> Chickening in!")
        claimable_amount = self.tax_and_chicken_in(chicken, chick, claimable_amount)

        # Provide liquidity to TOKEN/sTOKEN pool
        #print("\n \033[32mAdd liquidity!\033[0m \n")
        token_liquidity_amount = min(
            chicken.stoken_amm.get_A_amount_for_liquidity(claimable_amount) * 0.9999,
            chicken.token.balance_of(chick.account)
        )
        if token_liquidity_amount > 0:
            chicken.stoken_amm.add_liquidity(chick.account, token_liquidity_amount, claimable_amount)
        #print(chicken.stoken_amm)

        return 1

    def regular_chicken_in(self, chicken, chick, claimable_amount, iteration):
        # use actual stoken price instead of weighted average
        stoken_price = self.get_stoken_spot_price(chicken)
        # If the chicks profit are below their target_profit,
        # do neither chicken-in nor chicken-up.
        profit = claimable_amount * stoken_price - chick.bond_amount
        target_profit = chick.bond_target_profit * chick.bond_amount
        if profit <= target_profit:
            self.chicken_in_locked += 1
            # except for bootstrappers
            if not self.is_bootstrap_chicken_in(chick, iteration):
                """
                print("\n \033[31mProfit not reached!\033[0m")
                print(chick)
                print(f"\033[34mprice:            {stoken_price:,.2f}\033[0m")
                print(f"profit: {profit:,.2f}")
                print(f"target_profit: {target_profit:,.2f}")
                """
                return 0

        #print("\n --> Chickening in!")
        claimable_amount = self.tax_and_chicken_in(chicken, chick, claimable_amount)

        return 1

    def chicken_in(self, chicken, chick, iteration, data):
        """ User may chicken-in if the have already exceeded the break-even
        point of their investment and not yet exceeded the bonding cap.

        @param chicken: The resources.
        @param chick: The user
        @param iteration: The iteration step
        @param data: Logging data
        """

        if iteration < BOOTSTRAP_ITERATION:
            return 0, 0, 0

        claimable_amount, bond_cap = self.get_claimable_amount(chicken, chick, iteration)
        if claimable_amount == 0:
            return
        amm_token_amount, amm_coll_amount = self.get_amm_amounts(chicken, bond_cap, claimable_amount)

        """
        if chick.account == 'chick_72':
            print("")
            print(chick)
            print("-- Chicken in")
            print(f"claimable_amount: {claimable_amount:,.2f}")
            print(f"bond cap:         {bond_cap:,.2f}")
            print(f"bond amount:      {chick.bond_amount:,.2f}")
            print(f"bond time:        {chick.bond_time}")
            print(f"amm amount:       {amm_token_amount:,.2f}")
            print(f"pol ratio:        {self.get_pol_ratio(chicken):,.2f}")
            print(f"new pol amount:   {chick.bond_amount - 2*amm_token_amount:,.2f}")
            print(f"new ratio:        {(chick.bond_amount - 2*amm_token_amount) / claimable_amount:,.2f}")
        """

        if chick.rebonder:
            # Rebond
            #print("\n \033[33m--> Rebonding!\033[0m")
            new_chicken_in = self.rebond(chicken, chick, claimable_amount, iteration)
        elif chick.lp:
            #print("\n \033[33m--> LP!\033[0m")
            new_chicken_in = self.lp_chicken_in(chicken, chick, claimable_amount, iteration)
        else:
            #print("\n \033[33m--> regular!\033[0m")
            new_chicken_in = self.regular_chicken_in(chicken, chick, claimable_amount, iteration)

        self.chicken_in_counter += new_chicken_in

        # Redirect part of bond to AMM
        if amm_token_amount > 0 and new_chicken_in > 0:
            #print("\n --> Diverting!")
            self.divert_to_amm(chicken, amm_token_amount, amm_coll_amount)

        return
