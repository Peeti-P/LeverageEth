// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

interface Comptroller{
    function getAccountLiquidity(address account) external view returns (uint, uint, uint);
}

interface Erc20 {
    function approve(address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);
}

interface CErc20 {
    function mint(uint256) external returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function supplyRatePerBlock() external returns (uint256);

    function redeem(uint) external returns (uint);

    function redeemUnderlying(uint) external returns (uint);

    function borrow(uint256) external returns (uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function borrowBalanceCurrent(address) external returns (uint256);

    function repayBorrow(uint256) external returns (uint256);
}


interface CEth {
    function mint() external payable;

    function exchangeRateCurrent() external returns (uint256);

    function supplyRatePerBlock() external returns (uint256);

    function redeem(uint) external returns (uint);

    function redeemUnderlying(uint) external returns (uint);

    function balanceOf(address owner) external view returns (uint);
}

interface PriceFeed {
    function getUnderlyingPrice(address cToken) external view returns (uint);
}


contract LeveragePls {
    event MyLog(string, uint256);
    address payable CEth_address = payable(0x20572e4c090f15667cF7378e16FaD2eA0e2f3EfF);  
    mapping(address=>uint) CEthbalance;

    // function to check individual Ceth balance;
    function check_address_balance(
        address _address) 
        external view returns(uint)
        {
        return CEthbalance[_address];
    }

    function supplyEthToCompound()
        public
        payable
        returns (bool)
    {
        uint previous_balance;
        uint new_balance;
        // Create a reference to the corresponding cToken contract
        CEth cToken = CEth(CEth_address);
        // Record previous balance of CEth
        previous_balance = cToken.balanceOf(address(this));
        // Mint CEth
        cToken.mint{ value: msg.value, gas: 300000 }();
        // Record new balance of CEth
        new_balance = cToken.balanceOf(address(this));
        // Record CEth for each individual
        CEthbalance[msg.sender] += (new_balance - previous_balance);
        return true;
    }
    //1000000000000000
    //0x065eE5Dfc2Ced07dD49DaCB7849cE2F84EaABA0E

    function redeemCEth() 
        public 
        returns (bool) 
        {
        // Create a reference to the corresponding cToken contract
        CEth cToken = CEth(0x20572e4c090f15667cF7378e16FaD2eA0e2f3EfF);
        require(cToken.redeem(CEthbalance[msg.sender]) == 0, "something went wrong");
        CEthbalance[msg.sender] -= CEthbalance[msg.sender];
        return true;
    }

    // dai 0xdc31ee1784292379fbb2964b3b9c4124d8f89c60
    // cdai 0x822397d9a55d0fefd20f5c4bcab33c5f65bd28eb

    // borrow 10000000000
    function borrowDai()public payable{
        CErc20 cToken = CErc20(0x822397d9a55d0fefd20F5c4bCaB33C5F65bd28Eb);
        require(cToken.borrow(1000) == 0, "got collateral?");
    }

    function getAccountLiquidity(address _account) public view returns (uint, uint, uint){
        Comptroller comp = Comptroller(0x627EA49279FD0dE89186A58b8758aD02B6Be2867);
        (uint error, uint liquidity, uint shortfall) = comp.getAccountLiquidity(msg.sender);
        return (error, liquidity, shortfall);
    }

    // This is needed to receive ETH when calling `redeemCEth`
    receive() external payable {}
}
