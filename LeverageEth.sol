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
}

interface CEth {
    function mint() external payable;
    function exchangeRateCurrent() external returns (uint256);
    function supplyRatePerBlock() external returns (uint256);
    function redeem(uint) external returns (uint);
    function redeemUnderlying(uint) external returns (uint);
    function balanceOf(address owner) external view returns (uint);
}

//0x9A536Ed5C97686988F93C9f7C2A390bF3B59c0ec price oracle contract
interface PriceFeed {
    function getUnderlyingPrice(address cToken) external view returns (uint);
}


contract LeveragePls {
    event MyLog(string, uint256);
    address payable CEth_address = payable(0x20572e4c090f15667cF7378e16FaD2eA0e2f3EfF);  
    // mapping(address=>uint) CEthbalance;

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
        // CEthbalance[msg.sender] += (new_balance - previous_balance);
        return true;
    }
    //1000000000000000 wei or 0.001 eth or -> 0.1 usd
    //0x065eE5Dfc2Ced07dD49DaCB7849cE2F84EaABA0E wallet address

    function redeemCEth() 
        public 
        returns (bool) 
        {
        // Create a reference to the corresponding cToken contract
        CEth cToken = CEth(0x20572e4c090f15667cF7378e16FaD2eA0e2f3EfF);
        uint Ctoken_amount = cToken.balanceOf(address(this));
        require(cToken.redeem(Ctoken_amount) == 0, "something went wrong");
        return true;
    }

    // dai 0xdc31ee1784292379fbb2964b3b9c4124d8f89c60
    // cdai 0x822397d9a55d0fefd20f5c4bcab33c5f65bd28eb

    // borrow 100000000000000000 or 0.1 Dai
    function borrowDai(uint _borrowAmount) public payable{
        CErc20 cToken = CErc20(0x822397d9a55d0fefd20F5c4bCaB33C5F65bd28Eb);
        require(cToken.borrow(_borrowAmount) == 0, "got collateral?");
    }

    function getAccountLiquidity() public view returns (uint, uint, uint){
        Comptroller comp = Comptroller(0x627EA49279FD0dE89186A58b8758aD02B6Be2867);
        (uint error, uint liquidity, uint shortfall) = comp.getAccountLiquidity(address(this));
        return (error, liquidity, shortfall);
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
        Comptroller comp = Comptroller(0x627EA49279FD0dE89186A58b8758aD02B6Be2867);
        address[] memory markets = new address[](1);
        markets[0] = 0x20572e4c090f15667cF7378e16FaD2eA0e2f3EfF;
        comp.enterMarkets(markets);
    }

    function repay_dai() public {
        Erc20 Dai_interface = Erc20(0xdc31Ee1784292379Fbb2964b3B9C4124D8F89C60);
        CErc20 cToken = CErc20(0x822397d9a55d0fefd20F5c4bCaB33C5F65bd28Eb);
        Dai_interface.approve(0x822397d9a55d0fefd20F5c4bCaB33C5F65bd28Eb, Dai_interface.balanceOf(address(this)));
        cToken.repayBorrow((2**256)-1);
    }

    function repay_dai2(uint _amount) public {
        Erc20 Dai_interface = Erc20(0xdc31Ee1784292379Fbb2964b3B9C4124D8F89C60);
        CErc20 cToken = CErc20(0x822397d9a55d0fefd20F5c4bCaB33C5F65bd28Eb);
        Dai_interface.approve(0x822397d9a55d0fefd20F5c4bCaB33C5F65bd28Eb, Dai_interface.balanceOf(address(this)));
        cToken.repayBorrow(_amount);
    }

    // This is needed to receive ETH when calling `redeemCEth`
    receive() external payable {}
}
