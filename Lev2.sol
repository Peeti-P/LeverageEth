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

interface uniswapRounter {
    function WETH() external pure returns (address);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) external payable returns (uint[] memory amounts);
}

//0x7BBF806F69ea21Ea9B8Af061AD0C1c41913063A1 price oracle contract
interface EthPriceFeed {
    function getUnderlyingPrice(CEth) external view returns (uint);
}


contract LeveragePls {
    // Address of the deployed contracts on Ropsten Testnet
    address uniswap_rounter_address = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address cDai_address = 0xbc689667C13FB2a04f09272753760E38a95B998C;
    address cEth_adress = 0x859e9d8a4edadfEDb5A2fF311243af80F85A91b8;
    address dai_address = 0x31F42841c2db5173425b5223809CF3A38FEde360;
    uniswapRounter uniswap_interface = uniswapRounter(uniswap_rounter_address);
    Comptroller comp_interface = Comptroller(0xcfa7b0e37f5AC60f3ae25226F5e39ec59AD26152);
    EthPriceFeed oracle_interface = EthPriceFeed(0x7BBF806F69ea21Ea9B8Af061AD0C1c41913063A1);
    Erc20 Dai_interface = Erc20(dai_address);
    CEth Ceth_interface = CEth(cEth_adress);
    CErc20 cDai_interface = CErc20(cDai_address);

    function openPosition() 
        public 
        payable 
        returns (bool) {
        uint contributeAmount = msg.value;
        uint EthPrice = EthpriceOracle();
        uint borrow_amount = EthPrice*contributeAmount;
        Ceth_interface.mint{value: contributeAmount, gas: 300000 }();
        enterMarket();
        borrowDai(borrow_amount);
        daiToEth(borrow_amount);
        return true;
    }

    function EthpriceOracle() public view returns 
        (
        uint)
    {
        return oracle_interface.getUnderlyingPrice(Ceth_interface)/(10**18);
    }

    // function supplyEthToCompound()
    //     public
    //     payable
    //     returns (bool) {
    //     // Mint CEth
    //     Ceth_interface.mint{value: msg.value, gas: 300000 }();
    //     return true;
    // }
    
    //1000000000000000 wei or 0.01 eth or -> 0.1 usd
    //0x065eE5Dfc2Ced07dD49DaCB7849cE2F84EaABA0E wallet address

    // function redeemCEth() 
    //     public 
    //     returns (bool) 
    //     {
    //     uint Ctoken_amount = Ceth_interface.balanceOf(address(this));
    //     require(Ceth_interface.redeem(Ctoken_amount) == 0, "Something went wrong");
    //     return true;
    // }

    function redeemCEth(uint _amount) 
        public 
        returns (bool) 
        {
        // uint Ctoken_amount = Ceth_interface.balanceOf(address(this));
        require(Ceth_interface.redeem(_amount) == 0, "Something went wrong");
        return true;
    }

    // borrow 1000000000000000000 or 1 Dai
    function borrowDai(
        uint _borrowAmount) 
        public 
        payable {
        require(cDai_interface.borrow(_borrowAmount) == 0, "got collateral?");
    }

    function getAccountLiquidity() 
        public
        view 
        returns (uint, uint, uint)
        {
        // Comptroller comp = Comptroller(comptroller_address);
        (uint error, uint liquidity, uint shortfall) = comp_interface.getAccountLiquidity(address(this));
        return (error, liquidity, shortfall);
    }

    function currentEth() 
        public 
        view 
        returns(uint)
        {
        uint amount_temp = (Ceth_interface.exchangeRateStored() * Ceth_interface.balanceOf(address(this)))/10**18;
        return amount_temp;
    }

    function sendViaCall(
        address payable _to
        ) 
        public 
        payable {
        (bool sent, bytes memory data) = _to.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }

    function sendMoneyBack() 
        public 
        {
        address payable to_sender = payable(msg.sender);
        sendViaCall(to_sender);
    }

    function enterMarket() 
        public 
        {
        address[] memory markets = new address[](1);
        markets[0] = cEth_adress;
        comp_interface.enterMarkets(markets);
    }

    // function repay_dai() public {
    //     Dai_interface.approve(cDai_address, Dai_interface.balanceOf(address(this)));
    //     cDai_interface.repayBorrow((2**256)-1);
    // }

    function repayDai(uint _amount) 
        public 
        {
        Dai_interface.approve(cDai_address, Dai_interface.balanceOf(address(this)));
        cDai_interface.repayBorrow(_amount);
    }

    function daiToEth(uint _amount) 
        public 
        {
        require(Dai_interface.approve(address(uniswap_rounter_address), Dai_interface.balanceOf(address(this))), "approve failed.");
        address[] memory path = new address[](2);
        path[0] = address(dai_address);
        path[1] = uniswap_interface.WETH();
        uniswap_interface.swapExactTokensForETH(_amount, 0, path, address(this), block.timestamp);
    }

    function ethToDai(uint _amount) public {
        require(Dai_interface.approve(address(uniswap_rounter_address), Dai_interface.balanceOf(address(this))), "approve failed.");
        address[] memory path = new address[](2);
        path[0] = uniswap_interface.WETH();
        path[1] = address(dai_address);
        uniswap_interface.swapExactETHForTokens{value: _amount }(0, path, address(this), block.timestamp);
    }

    // This is needed to receive ETH when calling `redeemCEth`
    receive() external payable {}
}
