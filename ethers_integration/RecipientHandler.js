//import { ethers } from 'ethers';

// Contract ABI - Add your full ABI here
const RECIPIENT_HANDLER_ABI = [
  "function payWithEIP712((address buyer, address payTo, address paymentToken, uint256 totalAmount, uint256 nonce, bytes32 quoteId, uint128 serviceId, uint64 deadline) order, bytes sig, (bytes32 quoteId, address paymentToken, address seller, uint256 price, uint256 cost, uint128 serviceId, uint64 expiry) quote, bytes sellerQuoteSig, bytes permit2612, bytes permit2Data) external",
  "function claim(address token, uint256 claimAmount) external",
  "function revokeQuote((bytes32 quoteId, address paymentToken, address seller, uint256 price, uint256 cost, uint128 serviceId, uint64 expiry) quote, bytes sellerQuoteSig) external",
  "function unrevokeQuote((bytes32 quoteId, address paymentToken, address seller, uint256 price, uint256 cost, uint128 serviceId, uint64 expiry) quote, bytes sellerQuoteSig) external",
  "function setServiceActive(uint128 serviceId) external",
  "function createService(uint128 serviceId, address seller) external",
  "function nextNonce(address user) external view returns (uint256)",
  "function nonces(address owner) external view returns (uint256)",
  "function commissionRate() external view returns (uint256)",
  "function revokedQuote(bytes32) external view returns (bool)",
  // Events
  "event UserPaid(address indexed buyer, address indexed seller, uint256 totalAmount, uint128 serviceId)",
  "event SellerClaimed(address indexed seller, address indexed token, uint256 claimAmount)",
  "event QuoteRevoked(address indexed seller, bytes32 indexed quoteId)",
  "event QuoteUnrevoked(address indexed seller, bytes32 indexed quoteId)",
  "event CreatedService(address indexed seller, uint128 indexed serviceId)"
];

// EIP-712 Domain and Type Definitions
const EIP712_DOMAIN = {
  name: 'RecipientHandler', // Update with your contract's name
  version: '1', // Update with your contract's version
  chainId: null, // Will be set dynamically
  verifyingContract: 0xfc5B00Ab67CDd589c88E6eb7450d0806D5fcE1d9 // Will be set to contract address
};

const ORDER_TYPES = {
  Order: [
    { name: 'buyer', type: 'address' },
    { name: 'payTo', type: 'address' },
    { name: 'paymentToken', type: 'address' },
    { name: 'totalAmount', type: 'uint256' },
    { name: 'nonce', type: 'uint256' },
    { name: 'quoteId', type: 'bytes32' },
    { name: 'serviceId', type: 'uint128' },
    { name: 'deadline', type: 'uint64' }
  ]
};

const PRICEQUOTE_TYPES = {
  PriceQuote: [
    { name: 'quoteId', type: 'bytes32' },
    { name: 'paymentToken', type: 'address' },
    { name: 'seller', type: 'address' },
    { name: 'price', type: 'uint256' },
    { name: 'cost', type: 'uint256' },
    { name: 'serviceId', type: 'uint128' },
    { name: 'expiry', type: 'uint64' }
  ]
};

class RecipientHandlerContract {
  constructor(contractAddress) {
    this.contractAddress = contractAddress;
    this.provider = null;
    this.signer = null;
    this.contract = null;
    this.readOnlyContract = null;
  }

  /**
   * Initialize provider (read-only access)
   */
  async initProvider() {
    if (!window.ethereum) {
      throw new Error('MetaMask is not installed');
    }
    this.provider = new ethers.BrowserProvider(window.ethereum);
    this.readOnlyContract = new ethers.Contract(
      this.contractAddress,
      RECIPIENT_HANDLER_ABI,
      this.provider
    );
    return this.provider;
  }

  /**
   * Connect wallet and get signer (for transactions)
   */
  async connectWallet() {
    if (!window.ethereum) {
      throw new Error('MetaMask is not installed');
    }

    try {
      // Request account access
      await window.ethereum.request({ method: 'eth_requestAccounts' });
      
      this.provider = new ethers.BrowserProvider(window.ethereum);
      this.signer = await this.provider.getSigner();
      this.contract = new ethers.Contract(
        this.contractAddress,
        RECIPIENT_HANDLER_ABI,
        this.signer
      );

      const address = await this.signer.getAddress();
      const network = await this.provider.getNetwork();

      return {
        address,
        chainId: network.chainId,
        signer: this.signer
      };
    } catch (error) {
      throw new Error(`Failed to connect wallet: ${error.message}`);
    }
  }

  /**
   * Get connected wallet address
   */
  async getConnectedAddress() {
    if (!this.signer) {
      throw new Error('Wallet not connected. Call connectWallet() first');
    }
    return await this.signer.getAddress();
  }

  /**
   * Check if wallet is connected
   */
  isWalletConnected() {
    return this.signer !== null;
  }

  /**
   * Disconnect wallet
   */
  disconnectWallet() {
    this.signer = null;
    this.contract = null;
  }

  /**
   * Listen for account changes
   */
  onAccountsChanged(callback) {
    if (!window.ethereum) return;
    
    window.ethereum.on('accountsChanged', async (accounts) => {
      if (accounts.length === 0) {
        this.disconnectWallet();
        callback(null);
      } else {
        await this.connectWallet();
        callback(accounts[0]);
      }
    });
  }

  /**
   * Listen for network changes
   */
  onChainChanged(callback) {
    if (!window.ethereum) return;
    
    window.ethereum.on('chainChanged', (chainId) => {
      // Reload is recommended by MetaMask
      callback(chainId);
      window.location.reload();
    });
  }

  /**
   * Get the domain for EIP-712 signing
   */
  async getDomain() {
    if (!this.provider) {
      await this.initProvider();
    }
    const network = await this.provider.getNetwork();
    return {
      ...EIP712_DOMAIN,
      chainId: network.chainId,
      verifyingContract: this.contractAddress
    };
  }

  /**
   * Get next nonce for a user (read-only, doesn't need wallet connection)
   */
  async getNextNonce(userAddress) {
    if (!this.readOnlyContract && !this.contract) {
      await this.initProvider();
    }
    const contractToUse = this.contract || this.readOnlyContract;
    return await contractToUse.nextNonce(userAddress);
  }

  /**
   * Sign an Order (buyer signs) - requires wallet connection
   */
  async signOrder(orderData) {
    if (!this.signer) {
      throw new Error('Wallet not connected. Call connectWallet() first');
    }
    const domain = await this.getDomain();
    const signature = await this.signer.signTypedData(domain, ORDER_TYPES, orderData);
    return signature;
  }

  /**
   * Sign a PriceQuote (seller signs) - requires wallet connection
   */
  async signPriceQuote(quoteData) {
    if (!this.signer) {
      throw new Error('Wallet not connected. Call connectWallet() first');
    }
    const domain = await this.getDomain();
    const signature = await this.signer.signTypedData(domain, PRICEQUOTE_TYPES, quoteData);
    return signature;
  }

  /**
   * Create an order object
   */
  createOrder(buyer, paymentToken, totalAmount, nonce, quoteId, serviceId, deadline) {
    return {
      buyer,
      payTo: this.contractAddress, // Always pay to the contract
      paymentToken,
      totalAmount,
      nonce,
      quoteId,
      serviceId,
      deadline
    };
  }

  /**
   * Create a price quote object
   */
  createPriceQuote(quoteId, paymentToken, seller, price, cost, serviceId, expiry) {
    return {
      quoteId,
      paymentToken,
      seller,
      price,
      cost,
      serviceId,
      expiry
    };
  }

  /**
   * Pay with EIP712 (main payment function) - requires wallet connection
   */
  async payWithEIP712(order, orderSig, quote, sellerQuoteSig, permit2612 = '0x', permit2Data = '0x') {
    if (!this.contract) {
      throw new Error('Wallet not connected. Call connectWallet() first');
    }
    const tx = await this.contract.payWithEIP712(
      order,
      orderSig,
      quote,
      sellerQuoteSig,
      permit2612,
      permit2Data
    );
    return await tx.wait();
  }

  /**
   * Complete payment flow for buyer - requires wallet connection
   */
  async executeBuyerPayment(quoteData, sellerQuoteSig, permitData = {}) {
    if (!this.signer) {
      throw new Error('Wallet not connected. Call connectWallet() first');
    }

    const buyerAddress = await this.signer.getAddress();
    const nonce = await this.getNextNonce(buyerAddress);
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

    // Create order
    const order = this.createOrder(
      buyerAddress,
      quoteData.paymentToken,
      quoteData.price,
      nonce,
      quoteData.quoteId,
      quoteData.serviceId,
      deadline
    );

    // Sign order
    const orderSig = await this.signOrder(order);

    // Execute payment
    return await this.payWithEIP712(
      order,
      orderSig,
      quoteData,
      sellerQuoteSig,
      permitData.permit2612 || '0x',
      permitData.permit2Data || '0x'
    );
  }

  /**
   * Seller claims their profit - requires wallet connection
   */
  async claim(tokenAddress, amount) {
    if (!this.contract) {
      throw new Error('Wallet not connected. Call connectWallet() first');
    }
    const tx = await this.contract.claim(tokenAddress, amount);
    return await tx.wait();
  }

  /**
   * Revoke a quote (seller only) - requires wallet connection
   */
  async revokeQuote(quote, sellerQuoteSig) {
    if (!this.contract) {
      throw new Error('Wallet not connected. Call connectWallet() first');
    }
    const tx = await this.contract.revokeQuote(quote, sellerQuoteSig);
    return await tx.wait();
  }

  /**
   * Unrevoke a quote (seller only) - requires wallet connection
   */
  async unrevokeQuote(quote, sellerQuoteSig) {
    if (!this.contract) {
      throw new Error('Wallet not connected. Call connectWallet() first');
    }
    const tx = await this.contract.unrevokeQuote(quote, sellerQuoteSig);
    return await tx.wait();
  }

  /**
   * Toggle service active status (seller only) - requires wallet connection
   */
  async setServiceActive(serviceId) {
    if (!this.contract) {
      throw new Error('Wallet not connected. Call connectWallet() first');
    }
    const tx = await this.contract.setServiceActive(serviceId);
    return await tx.wait();
  }

  /**
   * Check if a quote is revoked (read-only, doesn't need wallet connection)
   */
  async isQuoteRevoked(quoteId) {
    if (!this.readOnlyContract && !this.contract) {
      await this.initProvider();
    }
    const contractToUse = this.contract || this.readOnlyContract;
    return await contractToUse.revokedQuote(quoteId);
  }

  /**
   * Get commission rate (read-only, doesn't need wallet connection)
   */
  async getCommissionRate() {
    if (!this.readOnlyContract && !this.contract) {
      await this.initProvider();
    }
    const contractToUse = this.contract || this.readOnlyContract;
    return await contractToUse.commissionRate();
  }

  /**
   * Listen to UserPaid events
   */
  onUserPaid(callback) {
    const contractToUse = this.contract || this.readOnlyContract;
    if (!contractToUse) {
      throw new Error('Contract not initialized. Call initProvider() or connectWallet() first');
    }
    
    contractToUse.on('UserPaid', (buyer, seller, totalAmount, serviceId, event) => {
      callback({
        buyer,
        seller,
        totalAmount,
        serviceId,
        transactionHash: event.transactionHash,
        blockNumber: event.blockNumber
      });
    });
  }

  /**
   * Listen to SellerClaimed events
   */
  onSellerClaimed(callback) {
    const contractToUse = this.contract || this.readOnlyContract;
    if (!contractToUse) {
      throw new Error('Contract not initialized. Call initProvider() or connectWallet() first');
    }
    
    contractToUse.on('SellerClaimed', (seller, token, claimAmount, event) => {
      callback({
        seller,
        token,
        claimAmount,
        transactionHash: event.transactionHash,
        blockNumber: event.blockNumber
      });
    });
  }

  /**
   * Remove all listeners
   */
  removeAllListeners() {
    if (this.contract) {
      this.contract.removeAllListeners();
    }
    if (this.readOnlyContract) {
      this.readOnlyContract.removeAllListeners();
    }
  }
}

// Helper function to approve ERC20 tokens
async function approveToken(tokenAddress, spenderAddress, amount, signer) {
  const ERC20_ABI = [
    "function approve(address spender, uint256 amount) external returns (bool)",
    "function allowance(address owner, address spender) external view returns (uint256)"
  ];
  
  const tokenContract = new ethers.Contract(tokenAddress, ERC20_ABI, signer);
  const currentAllowance = await tokenContract.allowance(
    await signer.getAddress(),
    spenderAddress
  );

  if (currentAllowance < amount) {
    const tx = await tokenContract.approve(spenderAddress, amount);
    await tx.wait();
  }
}
export { RecipientHandlerContract, approveToken };

