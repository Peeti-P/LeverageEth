// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

interface Comptroller{
    function getAccountLiquidity(address account) external view returns (uint, uint, uint);
    function enterMarkets(address[] memory cTokens) external returns (uint[] memory);
}

interface Erc20 {
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address owner) external view returns (uint);
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
    function balanceOf(address owner) external view returns (uint);
}

interface CEth {
    function mint() external payable;
    function exchangeRateCurrent() external returns (uint256);
    function supplyRatePerBlock() external returns (uint256);
    function redeem(uint) external returns (uint);
    function redeemUnderlying(uint) external returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function balanceOfUnderlying(address owner) external returns (uint);
    function exchangeRateStored() external view returns (uint);
}

//0x9A536Ed5C97686988F93C9f7C2A390bF3B59c0ec price oracle contract
interface PriceFeed {
    function getUnderlyingPrice(address cToken) external view returns (uint);
}


contract LeveragePls {
    // event MyLog(string, uint256);
    // address payable CEth_address = payable(0x20572e4c090f15667cF7378e16FaD2eA0e2f3EfF);
    address cDai_address = 0xbc689667C13FB2a04f09272753760E38a95B998C;
    address cEth_adress = 0x859e9d8a4edadfEDb5A2fF311243af80F85A91b8;
    Comptroller comp_interface = Comptroller(0xcfa7b0e37f5AC60f3ae25226F5e39ec59AD26152);
    Erc20 Dai_interface = Erc20(0x31F42841c2db5173425b5223809CF3A38FEde360);
    CEth Ceth_interface = CEth(cEth_adress);
    CErc20 cDai_interface = CErc20(cDai_address);


    function supplyEthToCompound()
        public
        payable
        returns (bool)
    {
        // Mint CEth
        Ceth_interface.mint{ value: msg.value, gas: 300000 }();
        return true;
    }
    
    //1000000000000000 wei or 0.001 eth or -> 0.1 usd
    //0x065eE5Dfc2Ced07dD49DaCB7849cE2F84EaABA0E wallet address

    function redeemCEth() 
        public 
        returns (bool) 
        {
        uint Ctoken_amount = Ceth_interface.balanceOf(address(this));
        require(Ceth_interface.redeem(Ctoken_amount) == 0, "Something went wrong");
        return true;
    }

    // dai 0xdc31ee1784292379fbb2964b3b9c4124d8f89c60
    // cdai 0x822397d9a55d0fefd20f5c4bcab33c5f65bd28eb

    // borrow 100000000000000000 or 0.1 Dai
    function borrowDai(
        uint _borrowAmount) 
        public payable
        {
        require(cDai_interface.borrow(_borrowAmount) == 0, "got collateral?");
    }

    function getAccountLiquidity() public view returns (uint, uint, uint){
        // Comptroller comp = Comptroller(comptroller_address);
        (uint error, uint liquidity, uint shortfall) = comp_interface.getAccountLiquidity(address(this));
        return (error, liquidity, shortfall);
    }

    function currentEth() public view returns(uint){
        uint amount_temp = (Ceth_interface.exchangeRateStored() * Ceth_interface.balanceOf(address(this)))/10**18;
        return amount_temp;
    }

    function sendViaCall(address payable _to) public payable {
        // Call returns a boolean value indicating success or failure.
        // This is the current recommended method to use.
        (bool sent, bytes memory data) = _to.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }

    function send_money_back() public {
        address payable to_sender = payable(msg.sender);
        sendViaCall(to_sender);
    }

    function enter_market() public {
        address[] memory markets = new address[](1);
        markets[0] = cEth_adress;
        comp_interface.enterMarkets(markets);
    }

    function repay_dai() public {
        Dai_interface.approve(cDai_address, Dai_interface.balanceOf(address(this)));
        cDai_interface.repayBorrow((2**256)-1);
    }

    function repay_dai2(uint _amount) public {
        Dai_interface.approve(cDai_address, Dai_interface.balanceOf(address(this)));
        cDai_interface.repayBorrow(_amount);
    }

    // This is needed to receive ETH when calling `redeemCEth`
    receive() external payable {}
}
