# !/usr/bin/env python
# -*- coding: utf-8 -*-

import pytest
from lib import chicken, user, erc_token, utils
from lib import testers


class TestChicken:
    """ Test suite for the chicken class."""

    coll = erc_token.Token('COLL')
    lqty = erc_token.Token('LQTY')
    slqty = erc_token.Token('sLQTY')
    user = user.User("test_user")

    chicken = chicken.Chicken(coll_token=coll,
                              token=lqty,
                              stoken=slqty,
                              coop_account="Coop",
                              pol_account="POL",
                              amm_account="AMM",
                              amm_fee=0.1)

    def test_coop_token_balance(self):
        """ Test get the coop-token balance."""

        minting = 5
        self.chicken.token.mint(self.chicken.coop_account, minting)

        assert self.chicken.coop_token_balance() == minting

    def test_pol_token_balance(self):
        """ Test get the pol-token balance."""

        minting = 5
        self.chicken.token.mint(self.chicken.pol_account, minting)

        assert self.chicken.pol_token_balance() == minting

    def test_reserve_token_balance(self):
        """ Test get the reserve token balance."""

        minting = 5
        self.chicken.token.mint(self.chicken.coop_account, minting)
        self.chicken.token.mint(self.chicken.pol_account, minting)

        assert self.chicken.reserve_token_balance() == 2 * minting

    def test_bond(self):
        """ Test bonding in a new user."""

        minting = 20
        bonding = 10
        self.chicken.token.mint(self.user.account, minting)
        self.chicken.bond(self.user, bonding, 5, 0)
        assert self.user.bond_amount == bonding
        assert self.chicken.coop_token_balance() == bonding
        assert self.chicken.token.balance_of(self.user.account) == minting - bonding

        with pytest.raises(AssertionError):
            # Test reject double bonding
            self.chicken.bond(self.user, bonding, 20, 0)

    def test_chicken_in(self):
        """ Test chicken-in the bond by a user."""

        minting = 20
        bonding = 10
        self.chicken.token.mint(self.user.account, minting)
        self.chicken.bond(self.user, bonding, 5, 0)

        # Chicken in with claimable sLQTY of 100% bonded LQTY
        self.chicken.chicken_in(self.user, bonding)

        assert self.chicken.stoken.balance_of(self.user.account) == bonding
        assert self.chicken.coop_token_balance() == 0
        assert self.chicken.pol_token_balance() == bonding
        assert self.chicken.token.balance_of(self.user.account) == minting - bonding

    def test_chicken_out(self):
        """ Test redeeming the bond by a user."""

        minting = 20
        bonding = 10
        self.chicken.token.mint(self.user.account, minting)
        self.chicken.bond(self.user, bonding, 5, 0)

        # Chicken out with 100% claimable bonded LQTY
        self.chicken.chicken_out(self.user)

        assert self.chicken.token.balance_of(self.user.account) == minting
        assert self.chicken.stoken.balance_of(self.user.account) == 0
        assert self.chicken.coop_token_balance() == 0
        assert self.chicken.pol_token_balance() == 0
        assert self.user.bond_amount == 0


class TestTesters:
    """ ToDo"""

    # chicks = list(map(lambda chick: user.User(f"chick_{chick:02}"), range(10000)))
    # tester = testers.TesterIssuanceBonds(chicks)

    def test_chicken_out(self):
        """ ToDo """
        pass

    def test_chicken_in(self):
        """ ToDo """
        pass

    def test_chicken_up(self):
        """ ToDo """
        pass


class TestUtils:
    """ Test suite for the utils."""
    pass


class TestERCToken:
    """ Test suite for the ERC-Token."""
    token = erc_token.Token(symbol="test_token")
    account = "test_account"
    receiving_account = "receiving_test_account"

    def test_mint(self):
        """ Test minting new tokens."""
        minting = 1
        self.token.mint(self.account, minting)

        assert self.token.balance_of(self.account) == minting
        assert self.token.total_supply == minting

        with pytest.raises(AssertionError):
            self.token.mint(self.account, -minting)

    def test_burn(self):
        """ Test burning existing tokens."""
        burning = 1
        try:
            total_supply = self.token.total_supply
            assert total_supply >= burning
        except AssertionError:
            self.token.mint(self.account, burning)

        with pytest.raises(RuntimeError):
            self.token.burn(self.account, 2*self.token.balance_of(self.account))

        if self.token.total_supply <= 0:
            self.token.mint(self.account, max(2*abs(self.token.total_supply),
                                              burning))
            total_supply = self.token.total_supply

        self.token.burn(self.account, burning)
        assert self.token.total_supply == (total_supply - burning)

        with pytest.raises(RuntimeError):
            self.token.burn(self.account, 2*total_supply)

    def test_transfer(self):
        """ Test transferring tokens."""
        minting = 1
        self.token.mint(self.account, minting)
        self.token.transfer(self.account, self.receiving_account, minting)

        assert self.token.balance_of(self.account) == 0
        assert self.token.balance_of(self.receiving_account) == minting

        # ToDo: Is there a good way to make multiple assertions in pytest.raises?
        with pytest.raises(RuntimeError):
            # Test transferring from account with no budget
            self.token.transfer(self.account, self.receiving_account, minting)
        with pytest.raises(RuntimeError):
            # Test transferring more than the budget
            self.token.transfer(self.receiving_account, self.account, 5*minting)
        with pytest.raises(RuntimeError):
            # Test transferring from not existing account
            self.token.transfer("not_existing_account", self.receiving_account, minting)
        with pytest.raises(RuntimeError):
            # Test transferring negative amount, i.e. stealing from someone.
            # ToDo not implemented yet
            self.token.transfer(self.account, self.receiving_account, -minting)

    def test_get_balance_of(self):
        """ Test getting the balance of an account."""

        minting = 1
        self.token.mint(self.account, minting)

        assert minting == self.token.balance_of(self.account)
        assert self.token.balance_of("not_existing_account") == 0


class TestAMM:
    """ Test suite for the AMMs."""
    pass


class TestBaseTesters:
    """ Test suite for all testers."""
    pass

