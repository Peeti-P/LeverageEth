pragma solidity ^0.8.6;

interface Comptroller{
    function getAccountLiquidity(address account) external view returns (uint, uint, uint);
    function enterMarkets(address[] memory cTokens) external returns (uint[] memory);
    function markets(address) external view returns (bool, uint, bool);
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

interface EthPriceFeed {
    function getUnderlyingPrice(CEth) external view returns (uint);
}

/**
* @title LeverageETH contract
* @notice Smart Contract for leverage ETH position by 0-70%
* @author Peeti
 **/

contract LeverageETH {
    // Address of the deployed contracts on Ropsten Testnet
    address uniswap_rounter_address = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address cDai_address = 0xbc689667C13FB2a04f09272753760E38a95B998C;
    address cEth_adress = 0x859e9d8a4edadfEDb5A2fF311243af80F85A91b8;
    address dai_address = 0x31F42841c2db5173425b5223809CF3A38FEde360;
    
    // Interface of the contracts
    uniswapRounter uniswap_interface = uniswapRounter(uniswap_rounter_address);
    Comptroller comp_interface = Comptroller(0xcfa7b0e37f5AC60f3ae25226F5e39ec59AD26152);
    EthPriceFeed oracle_interface = EthPriceFeed(0x7BBF806F69ea21Ea9B8Af061AD0C1c41913063A1);
    Erc20 Dai_interface = Erc20(dai_address);
    CEth Ceth_interface = CEth(cEth_adress);
    CErc20 cDai_interface = CErc20(cDai_address);
    // To record loan amount
    uint borrow_amount;

    /**
    * @dev Open the Leveraged Position 
    * @param _leverageAmount the leverage amount (0-70%)
    **/
    function openPosition(uint _leverageAmount) 
        public 
        payable 
        returns (bool) {
        require(_leverageAmount > 0 && _leverageAmount <= 70, "Please input leverage amount between 0-70 (%)" );
        uint contributeAmount = msg.value;
        uint EthPrice = EthpriceOracle();
        borrow_amount = ((EthPrice*contributeAmount)*_leverageAmount/100);
        Ceth_interface.mint{value: contributeAmount, gas: 300000 }();
        enterMarket();
        borrowDai(borrow_amount);
        daiToEth(borrow_amount);
        return true;
    }

    /**
    * @dev Close the Leverage Position 
    **/
    function closePosition()
        public {
        uint exchangeRate = currentExchangeRate();
        uint collateralFactor = cEthCollateralFactor()+(5*(10**14));
        uint EthPrice = EthpriceOracle();
        uint liquidity;
        uint redeemable_amount;

        // Transform Ethereum to Dai via UniswapRounter
        ethToDai(address(this).balance);
        uint dai_balance = Dai_interface.balanceOf(address(this));

        // Check whether we can repay the loan amount in full or not
        if (dai_balance > borrow_amount){
            // repay in full
            repayDai(borrow_amount);
        }else{
            // partial repay
            repayDai(dai_balance);
        }
        liquidity = getAccountLiquidity();

        // Calculate amount of cETH we can retrieve back
        redeemable_amount = (liquidity*(10**36))/(collateralFactor*EthPrice*exchangeRate);

        //Redeem cETH to ETH
        redeemCEth(redeemable_amount);

        // Check if we get some profit or not (i.e. remaning dai after repay debt)
        // Becuase the mismatch of the price between Compound and Uniswap, we have to swap two times
        dai_balance = Dai_interface.balanceOf(address(this));
        if (dai_balance > 0){
            //transfer from Dai to Eth
            daiToEth(dai_balance);
        }

        // Send Money Back to the User
        sendMoneyBack();
    }

    /**
    * @dev Return cETH collateral factor
    **/
    function cEthCollateralFactor() 
        internal 
        view 
        returns (uint)
        {
        (bool temp_1, uint factor, bool temp_2) = comp_interface.markets(cEth_adress);
        return factor;
    }

    /**
    * @dev ETH Price Oracle provided by Compound on the Ropsten testnet (in USD)
    **/
    function EthpriceOracle() public view returns (
        uint
        )
        {
        return oracle_interface.getUnderlyingPrice(Ceth_interface)/(10**18);
    }
    
    /**
    * @dev ETH Price Oracle provided by Compound on the Ropsten testnet
    **/
    function supplyEthToCompound()
        public
        payable
        {
        // Mint CEth
        Ceth_interface.mint{value: msg.value, gas: 300000 }();
    }

    /**
    * @dev Redeem cETH for ETH
    * @param _amount amount of cETH to be redeemed
    **/
    function redeemCEth(
        uint _amount
        ) 
        public 
        returns (bool) 
        {
        require(Ceth_interface.redeem(_amount) == 0, "Something went wrong");
        return true;
    }

    /**
    * @dev borrow Dai from Compound
    * @param _borrowAmount amount of Dai to be borrowed
    **/
    function borrowDai(
        uint _borrowAmount
        ) 
        public 
        payable {
        cDai_interface.borrow(_borrowAmount);
    }

    /**
    * @dev get liquidity left in Compound (in USD)
    **/
    function getAccountLiquidity() 
        public
        view 
        returns (uint)
        {
        (uint error, uint liquidity, uint shortfall) = comp_interface.getAccountLiquidity(address(this));
        return liquidity;
    }

    /**
    * @dev get current exchange rate between cETH and ETH from Compound
    **/
    function currentExchangeRate() 
        public 
        view 
        returns(uint)
        {
        uint amount_temp = (Ceth_interface.exchangeRateStored());
        return amount_temp;
    }

    /**
    * @dev send ETH function
    * @param _to recipient address
    **/
    function sendViaCall(
        address payable _to
        ) 
        public 
        payable 
        {
        (bool sent, bytes memory data) = _to.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }

    /**
    * @dev send ETH back to user
    **/
    function sendMoneyBack() 
        public 
        {
        address payable to_sender = payable(msg.sender);
        sendViaCall(to_sender);
    }

    /**
    * @dev enable compound to use cETH as a collateral
    **/
    function enterMarket() 
        public 
        {
        address[] memory markets = new address[](1);
        markets[0] = cEth_adress;
        comp_interface.enterMarkets(markets);
    }

    /**
    * @dev repay dai in a specific amount
    * @param _amount amount of dai to be repaid in Compound
    **/
    function repayDai(
        uint _amount
        ) 
        public 
        {
        Dai_interface.approve(cDai_address, Dai_interface.balanceOf(address(this)));
        cDai_interface.repayBorrow(_amount);
    }

    /**
    * @dev swap dai to ETH via Uniswaprounter
    * @param _amount amount of Dai to be transformed to Eth
    **/
    function daiToEth(
        uint _amount
        ) 
        public 
        {
        require(Dai_interface.approve(address(uniswap_rounter_address), Dai_interface.balanceOf(address(this))), "approve failed.");
        address[] memory path = new address[](2);
        path[0] = address(dai_address);
        path[1] = uniswap_interface.WETH();
        // set minimum recive to 0 becuase uniswap on testnet has a huge price impact
        uniswap_interface.swapExactTokensForETH(_amount, 0, path, address(this), block.timestamp);
    }

    /**
    * @dev swap dai to ETH via Uniswaprounter
    * @param _amount amount of Eth to be transformed to Dai
    **/   
    function ethToDai(uint _amount) public {
        require(Dai_interface.approve(address(uniswap_rounter_address), Dai_interface.balanceOf(address(this))), "approve failed.");
        address[] memory path = new address[](2);
        path[0] = uniswap_interface.WETH();
        path[1] = address(dai_address);
        // set minimum recive to 0 becuase uniswap on testnet has a huge price impact
        uniswap_interface.swapExactETHForTokens{value: _amount }(0, path, address(this), block.timestamp);
    }

    // This is needed to receive ETH when calling `redeemCEth`
    receive() external payable {}
}
