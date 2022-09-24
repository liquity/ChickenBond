# @version 0.3.3

totalSupply: public(uint256)
balances: HashMap[address, uint256]

@external
def mint(_to: address, _value: uint256) -> bool:
    self.balances[_to] += _value
    self.totalSupply += _value
    return True

@external
def mint_relative(_to: address, frac: uint256) -> uint256:
    if self.totalSupply == 0:
       return 0
    value: uint256 = frac * 10**18 / self.totalSupply
    self.balances[_to] += value
    self.totalSupply += value
    return value

@external
def burnFrom(_to: address, _value: uint256) -> bool:
    self.balances[_to] -= _value
    self.totalSupply -= _value
    return True

@external
@view
def balanceOf(_user: address) -> uint256:
    return self.balances[_user]
