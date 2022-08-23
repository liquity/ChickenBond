# !/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
import inspect

currentdir = os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe())))
parentdir = os.path.dirname(currentdir)
sys.path.insert(0, parentdir)

import pytest
from lib import chicken, user, erc_token, utils
from lib import testers


class TestChicken:
    """ Test suite for the chicken class."""

    coll = erc_token.Token('COLL')
    lqty = erc_token.Token('LQTY')
    blqty = erc_token.Token('bLQTY')
    user = user.User("test_user")

    chicken = chicken.Chicken(coll_token=coll,
                              token=lqty,
                              btkn=blqty,
                              pending_account="Pending",
                              reserve_account="RESERVE",
                              amm_account="AMM",
                              amm_fee=0.1)

    def test_pending_token_balance(self):
        """ Test get the pending-token balance."""

        minting = 5
        self.chicken.token.mint(self.chicken.pending_account, minting)

        assert self.chicken.pending_token_balance() == minting
        # Reset the initial state
        self.chicken.token.burn(self.chicken.pending_account, minting)

    def test_reserve_token_balance(self):
        """ Test get the reserve-token balance."""

        minting = 5
        self.chicken.token.mint(self.chicken.reserve_account, minting)

        assert self.chicken.reserve_token_balance() == minting
        # Reset the initial state
        self.chicken.token.burn(self.chicken.reserve_account, minting)

    def test_reserve_token_balance(self):
        """ Test get the reserve token balance."""

        minting = 5
        self.chicken.token.mint(self.chicken.pending_account, minting)
        self.chicken.token.mint(self.chicken.reserve_account, minting)

        assert self.chicken.reserve_token_balance() == 2 * minting
        # Reset the initial state
        self.chicken.token.burn(self.chicken.pending_account, minting)
        self.chicken.token.burn(self.chicken.reserve_account, minting)

    def test_bond(self):
        """ Test bonding in a new user."""

        minting = 20
        bonding = 10
        self.chicken.token.mint(self.user.account, minting)
        self.chicken.bond(self.user, bonding, 5, 0)
        assert self.user.bond_amount == bonding
        assert self.chicken.pending_token_balance() == bonding
        assert self.chicken.token.balance_of(self.user.account) == minting - bonding

        with pytest.raises(AssertionError):
            # Test reject double bonding
            self.chicken.bond(self.user, bonding, 20, 0)

        # Reset the initial state
        self.chicken.chicken_out(self.user)
        self.chicken.token.burn(self.user.account, minting)

    def test_chicken_in(self):
        """ Test chicken-in the bond by a user."""

        minting = 20
        bonding = 10
        self.chicken.token.mint(self.user.account, minting)
        self.chicken.bond(self.user, bonding, 5, 0)

        # Chicken in with claimable bLQTY of 100% bonded LQTY
        self.chicken.chicken_in(self.user, bonding)

        assert self.chicken.btkn.balance_of(self.user.account) == bonding
        assert self.chicken.pending_token_balance() == 0
        assert self.chicken.reserve_token_balance() == bonding
        assert self.chicken.token.balance_of(self.user.account) == minting - bonding

        # Reset the initial state
        self.chicken.token.burn(self.user.account, minting - bonding)
        self.chicken.reserve_account = 0
        self.chicken.btkn.balances = {}

    def test_chicken_out(self):
        """ Test redeeming the bond by a user."""

        minting = 20
        bonding = 10
        self.chicken.token.mint(self.user.account, minting)
        self.chicken.bond(self.user, bonding, 5, 0)

        # Chicken out with 100% claimable bonded LQTY
        self.chicken.chicken_out(self.user)

        assert self.chicken.token.balance_of(self.user.account) == minting
        assert self.chicken.btkn.balance_of(self.user.account) == 0
        assert self.chicken.pending_token_balance() == 0
        assert self.chicken.reserve_token_balance() == 0
        assert self.user.bond_amount == 0

        # Reset the inital state
        self.chicken.token.burn(self.user.account, minting)


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

        # ToDo: Not implemented yet
        # with pytest.raises(AssertionError):
        #     self.token.mint(self.account, -minting)

        # Reset the inital state
        self.token.burn(self.account, minting)

    def test_burn(self):
        """ Test burning existing tokens."""
        burning = 1
        try:
            total_supply = self.token.total_supply
            assert total_supply >= burning
        except AssertionError:
            self.token.mint(self.account, burning)

        with pytest.raises(RuntimeError):
            self.token.burn(self.account, 2 * self.token.balance_of(self.account))

        if self.token.total_supply <= 0:
            self.token.mint(self.account, max(2 * abs(self.token.total_supply),
                                              burning))
            total_supply = self.token.total_supply

        self.token.burn(self.account, burning)
        assert self.token.total_supply == (total_supply - burning)
        self.token.balance_of(self.account)

        with pytest.raises(RuntimeError):
            self.token.burn(self.account, 2 * total_supply)

        # Reset the initial state
        self.token.balances = {}

    def test_transfer(self):
        """ Test transferring tokens."""
        minting = 1
        self.token.mint(self.account, minting)
        self.token.transfer(self.account, self.receiving_account, minting)

        assert self.token.balance_of(self.account) == 0
        assert self.token.balance_of(self.receiving_account) == minting

        with pytest.raises(RuntimeError):
            # Test transferring from account with no budget
            self.token.transfer(self.account, self.receiving_account, minting)
        with pytest.raises(RuntimeError):
            # Test transferring more than the budget
            self.token.transfer(self.receiving_account, self.account, 5 * minting)
        with pytest.raises(RuntimeError):
            # Test transferring from not existing account
            self.token.transfer("not_existing_account", self.receiving_account, minting)
        # ToDo not implemented yet
        # with pytest.raises(RuntimeError):
        #     # Test transferring negative amount, i.e. stealing from someone.
        #     self.token.transfer(self.account, self.receiving_account, -minting)

        # Reset the inital state
        self.token.balances = {}

    def test_get_balance_of(self):
        """ Test getting the balance of an account."""

        minting = 1
        self.token.mint(self.account, minting)

        assert self.token.balance_of(self.account) == minting
        assert self.token.balance_of("not_existing_account") == 0


class TestAMM:
    """ Test suite for the AMMs."""
    pass


class TestBaseTesters:
    """ Test suite for all testers."""
    pass


class TestTesters:
    """ ToDo"""
    pass


class TestUtils:
    """ Test suite for the utils."""
    pass
