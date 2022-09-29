import pytest
from brownie import accounts, Contract, Token, CurveCryptoSwap2


CURVE_V2_A = 200000000
CURVE_V2_GAMMA = 19900000000000000
CURVE_V2_MID_FEE = 15000000
CURVE_V2_OUT_FEE = 30000000
CURVE_V2_ALLOWED_EXTRA_PROFIT = 100000000
CURVE_V2_FEE_GAMMA = 5000000000000000
CURVE_V2_ADJUSTMENT_STEP = 5500000000000
CURVE_V2_ADMIN_FEE = 5000000000
CURVE_V2_MA_HALF_TIME = 600
CURVE_V2_INITIAL_PRICE = 2570000000000000000

coin1 = None
coin2 = None

@pytest.fixture
def curve_v2_pool():
    token = accounts[0].deploy(Token, "LP Token", "LPT", 18, 0)
    coin1 = accounts[0].deploy(Token, "Coin 1", "C1T", 18, 1e24)
    coin2 = accounts[0].deploy(Token, "Coin 2", "C2T", 18, 1e24)
    return accounts[0].deploy(
        CurveCryptoSwap2,
        accounts[0],
        accounts[0],
        CURVE_V2_A,
        CURVE_V2_GAMMA,
        CURVE_V2_MID_FEE,
        CURVE_V2_OUT_FEE,
        CURVE_V2_ALLOWED_EXTRA_PROFIT,
        CURVE_V2_FEE_GAMMA,
        CURVE_V2_ADJUSTMENT_STEP,
        CURVE_V2_ADMIN_FEE,
        CURVE_V2_MA_HALF_TIME,
        CURVE_V2_INITIAL_PRICE,
        token.address,
        [coin1.address, coin2.address]
    )

def add_liquidity(curve_v2_pool, x, y):
    print(f"c1: {curve_v2_pool.coins(0)}")
    coin1 = Contract.from_abi("Token", curve_v2_pool.coins(0), Token.abi)
    coin2 = Contract.from_abi("Token", curve_v2_pool.coins(1), Token.abi)
    coin1.approve(curve_v2_pool.address, 1e32, { 'from': accounts[0] })
    coin2.approve(curve_v2_pool.address, 1e32, { 'from': accounts[0] })
    tx = curve_v2_pool.add_liquidity([x, y], 0, accounts[0], { 'from': accounts[0] })
    print(tx.events)
    #print(f"lp: {lp:,.2f}")
    return

def test_newton_y(curve_v2_pool):
    add_liquidity(curve_v2_pool, 136.65e18, 53.14e18)
    #print(f"xp: {curve_v2_pool.xp_wrapper()}")
    #dy = curve_v2_pool.get_dy(0, 1, 1e18)
    #dy = curve_v2_pool.get_dy(0, 1, 273.3e18)
    #assert dy == 1e18

    #y = curve_v2_pool.newton_y_wrapper(CURVE_V2_A, CURVE_V2_GAMMA, [137.65e18, 136.65e18], 273.30e18, 1)
    """
    y = curve_v2_pool.newton_y_wrapper(
        CURVE_V2_A,
        CURVE_V2_GAMMA,
        [
            137650000000000000000,
            136569800000000000000
        ],
        273219799998823025804,
        1
    )
    assert y == 1e18
    """

    tx = curve_v2_pool.exchange(0, 1, 72.88e18, 0, { 'from': accounts[0] })
    """
    tx = curve_v2_pool.tweak_price_wrapper(
        [
            CURVE_V2_A,
            CURVE_V2_GAMMA,
        ],
        [
            209.53e18,
            66.08e18
        ],
        2.66e18,
        0
    )
    """
    assert tx == 0
