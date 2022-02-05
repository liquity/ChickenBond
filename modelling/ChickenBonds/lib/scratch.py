#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Basic logic:

                                Chicken is Bonded?
                                /              \
                              YES               NO
                              /                  \
                        Runt?           CONTINUE
                          /      \
                        YES      NO
                        /          \
                  REACHED CAP?   CHICKEN-OUT,
                    /      \     CONTINUE
                  YES      NO
                  /         \
        OVER THE CAP?      CHICKEN-IN,
            /      \       CONTINUE
          YES      NO
          /          \
    CHICKEN-UP      CHICKEN_IN
    CHICKEN-UP_IN   CONTINUE
    CONTINUE

"""


def update_chicken(self, chicken, chicks, data, iteration):
    """ Update the state of each user. Users may:
        - chicken-out
        - chicken-in
        - chicken-up
    with predefined probabilities.

    :param chicken: The resources
    :param chicks: All users
    :param data: Logging data
    :param iteration: The iteration step
    """

    np.random.seed(2023 * iteration)
    np.random.shuffle(chicks)

    total_chicken_in_amount = 0
    total_chicken_out_amount = 0
    total_chicken_in_foregone = 0
    total_chicken_up_amount = 0
    bonded_chicks = self.get_bonded_chicks(chicks)

    for chick in bonded_chicks:

        assert iteration >= chick.bond_time
        pol_ratio = self.get_pol_ratio(chicken)
        assert pol_ratio == 0 or pol_ratio >= 1
        if pol_ratio == 0:
            pol_ratio = 1

        # -------------------------------
        # Chicken-out

        # Check if chicken-out conditions are met and eventually chicken-out
        total_chicken_out_amount += self.chicken_out(self, chicken, chick)

        # -------------------------------
        # Chicken-in

        # Check if chicken-out conditions are met and eventually chicken-out
        new_chicken_in_amount, new_chicken_in_forgone = self.chicken_in(self, chicken, chick, iteration, pol_ratio,
                                                                        data)
        total_chicken_in_amount += new_chicken_in_amount
        total_chicken_in_foregone += new_chicken_in_forgone

        # -------------------------------
        # Chicken-up

        # Check if chicken-out conditions are met and eventually chicken-out
        total_chicken_up_amount += self.chicken_up(self, chicken, chick, iteration, pol_ratio, data)


def chicken_in(self, chicken, chick, iteration, pol_ratio, data):
    """ User may chicken-in if the have already exceeded the break-even
    point of their investment and not yet exceeded the bonding cap.

    :param chicken: The resources.
    :param chick: The user
    :param iteration: The iteration step
    :param pol_ratio: The backing ration, i.e. POL/sLQTY
    :param data: Logging data
    :return: Amount of new claimable sLQTY and foregone amount.
    """

    mintable_amount, bond_cap, claimable_stoken, amm_token_amount, amm_stoken_amount = \
        self.get_claimable_stoken(chicken, chick, iteration, pol_ratio)

    # use actual stoken price instead of weighted average
    # stoken_price = self.get_stoken_price(chicken, data, iteration)
    stoken_price = self.get_stoken_spot_price(chicken, data, iteration)
    profit = claimable_stoken * stoken_price - chick.bond_amount
    target_profit = chick.bond_target_profit * chick.bond_amount

    max_claimable_stoken = self.get_accumulated_stoken(chick, iteration)
    # If the user reached the sLQTY cap, certainly chicken-up.
    if max_claimable_stoken > bond_cap or profit <= target_profit:
        # If the chicks profit are below their target_profit,
        # do neither chicken-in nor chicken-up.
        return 0, 0

    foregone_amount = chick.bond_amount - mintable_amount * stoken_price
    chicken.chicken_in(chick, claimable_stoken)

    return claimable_stoken, foregone_amount


def chicken_out(self, chicken, chick, iteration, data):
    """ Chicken  out defines leaving users. User are only allowed to leave if
    the break-even point of the investment is not reached with a predefined
    probability.

    :param chicken: Resources
    :param chick: All users
    :param iteration:
    :param data:
    :return: Total outgoing amount.
    """

    total_chicken_out_amount = 0
    bonded_chicks = self.get_bonded_chicks(chick)

    # use actual stoken price instead of weighted average
    # stoken_price = self.get_stoken_price(chicken, data, iteration)
    stoken_price = self.get_stoken_spot_price(chicken, data, iteration)
    max_claimable_stoken = self.get_accumulated_stoken(chick, iteration)
    profit = max_claimable_stoken * stoken_price - chick.bond_amount

    # if break even is not reached and chicken-out proba (10%) is fulfilled
    if profit <= 0 and np.random.binomial(1, self.chicken_out_probability) == 1:
        chicken.chicken_out(chick)
        total_chicken_out_amount += chick.bond_amount

    return total_chicken_out_amount


def chicken_up(self, chicken, chick, iteration, data):
    """ Chicken-ups are users enabling the access to additional sLQTY tokens.
    User are only allowed to chicken-up if they exceeded the bonding cap and
    only by the outstanding amount of sLQTY tokens.
    
    :param chicken: The reserve pool object.
    :param chick: The user
    :param bond_cap: The maximum claimable stoken amount before chicken-up
    :param iteration: The actual period
    :return: The new claimable and mint-able stoken amount
    """

    # use actual stoken price instead of weighted average
    # stoken_price = self.get_stoken_price(chicken, data, iteration)
    stoken_price = self.get_stoken_spot_price(chicken, data, iteration)
    max_claimable_stoken = self.get_accumulated_stoken(chick, iteration)

    # Check if the sLQTY cap is exceeded
    if max_claimable_stoken <= bond_cap:
        return 0

    # calculate the maximum amount of LQTY to chicken-up
    top_up_amount = min((max_claimable_stoken - bond_cap) * stoken_price,
                        chicken.token.balance_of(chick.account))

    # Calculate the claimable_amount as the minimum of max_claimable_amount and
    # the actual top_up_amount. If a chick is not able to chick_up to the total
    # max_claimable_stoken_amount.
    claimable_amount = min(max_claimable_stoken,
                           bond_cap + (top_up_amount / stoken_price))

    # Check if chicken-up is profitable
    # Profit = (ALL claimable sLQTY * Price) - (Initial investment + additional investment)
    profit = (claimable_amount * stoken_price) - (chick.bond_amount + top_up_amount)
    target_profit = chick.bond_target_profit * (chick.bond_amount + top_up_amount)

    if profit <= target_profit:
        return 0

    # Transfer the assets first to the COOP account, which is then transferred
    # to the POL account in chicken.chicken_in()
    chicken.token.transfer(chick.account, chicken.coop_account, top_up_amount)

    return claimable_amount
