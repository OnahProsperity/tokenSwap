// SPDX-License-Identifier: MIT
interface IERC20 {
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

// @dev using 0.8.0.
// Note: If changing this, Safe Math has to be implemented!
pragma solidity 0.8.0;
contract RGPTokenSale {
    
    address public busd = 0xCBb5615864Daad07d14f151CC83D016f90a1dD9d;
    address public rgp  = 0xc0179574369E6EF67b3a581E3a143eCE3EDB597E;
    address public owner;
    uint    public price;
    
    uint256 public tokensSold;
    uint256 public decimals;
    
    bool    public saleActive;
    
    // Emitted when tokens are sold
    event Sale(address indexed account, uint indexed price, uint cost, uint tokensGot);
    
    // Only allow the owner to do specific tasks
    modifier onlyOwner() {
        require(msg.sender == owner,"RGP TOKEN: YOU ARE NOT THE OWNER.");
        _;
    }

    constructor(uint _price) {
        owner =  msg.sender;
        saleActive = true;
        price = _price;
 
        // SMC: 0x652c9ACcC53e765e1d96e2455E618dAaB79bA595
    }
    
    // Change the token price
    // Note: Set the price respectively considering the decimals of busd
    // Example: If the intended price is 0.01 per token, call this function with the result of 0.01 * 10**18 (_price = intended price * 10**18; calc this in a calculator).
    function tokenPrice(uint _price) external onlyOwner {
        price = _price;
    }
    
    // Guards against integer overflows
    function mul(uint x, uint y) public pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }

    // Buy tokens function
    // Note: This function allows only purchases of "full" tokens, purchases of 0.1 tokens or 1.1 tokens for example are not possible
    function buyTokens(uint256 _tokenAmount) public {
        
        // Check if sale is active and user tries to buy atleast 1 token
        require(saleActive == true, "RGP: SALE HAS ENDED.");
        require(_tokenAmount >= 1, "RGP: BUY ATLEAST 1 TOKEN.");
        
        // Calculate the purchase cost
        uint256 cost = _tokenAmount * price;
        
        // Calculate the tokens msg.sender will get (with decimals)
        uint256 tokensToGet = mul(_tokenAmount, uint256(10) ** IERC20(busd).decimals()) / mul(price, uint256(10) ** IERC20(rgp).decimals());
        
        // Transfer busd from msg.sender to the contract
        // If it returns false/didn't work, the
        //  msg.sender may not have allowed the contract to spend busd or
        //  msg.sender or the contract may be frozen or
        //  msg.sender may not have enough busd to cover the transfer.
        //  ^ Check this via frontend to save gas
        require(IERC20(busd).transferFrom(msg.sender, address(this), cost), "RGP: TRANSFER OF BUSD FAILED!");
        
        // Transfer RGP to msg.sender
        // If it returns false/didn't work, the contract doesn't own enough tokens to cover the transfer
        require(IERC20(rgp).transfer(msg.sender, tokensToGet), "RGP: CONTRACT DOES NOT HAVE ENOUGH TOKENS.");
        
        tokensSold += tokensToGet;
        emit Sale(msg.sender, price, cost, tokensToGet);
    }

    // End the sale, don't allow any purchases anymore and send remaining rgp to the owner
    function disableSale() external onlyOwner{
        
        // End the sale
        saleActive = false;
        
        // Send unsold tokens and remaining busd to the owner. Only ends the sale when both calls are successful
        IERC20(rgp).transfer(owner, IERC20(rgp).balanceOf(address(this)));
    }
    
    // Start the sale again - can be called anytime again
    // To enable the sale, send RGP tokens to this contract
    function enableSale() external onlyOwner{
        
        // Enable the sale
        saleActive = true;
        
        // Check if the contract has any tokens to sell or cancel the enable
        require(IERC20(rgp).balanceOf(address(this)) >= 1, "RGP: CONTRACT DOES NOT HAVE TOKENS TO SELL.");
    }
    
    // Withdraw busd to _recipient
    function withdrawBUSD() external onlyOwner {
        uint _busdBalance = IERC20(busd).balanceOf(address(this));
        require(_busdBalance >= 1, "RGP: NO BUSD TO WITHDRAW");
        IERC20(busd).transfer(owner, _busdBalance);
    }
    
    // Withdraw (accidentally) to the contract sent eth
    function withdrawETH() external payable onlyOwner {
        payable(owner).transfer(payable(address(this)).balance);
    }
    
    // Withdraw (accidentally) to the contract sent ERC20 tokens except rgp
    function withdrawIERC20(address _token) external onlyOwner {
        uint _tokenBalance = IERC20(_token).balanceOf(address(this));
        
        // Don't allow RGP to be withdrawn (use endSale() instead)
        require(_tokenBalance >= 1 && _token != rgp, "RGP: CONTRACT DOES NOT OWN THAT TOKEN OR TOKEN IS RGP.");
        IERC20(_token).transfer(owner, _tokenBalance);
    }
}
