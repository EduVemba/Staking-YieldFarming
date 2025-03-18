// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BasicStaking is Ownable, ReentrancyGuard {
    // Token que será usado para staking
    IERC20 public immutable stakingToken;

    // Taxa de recompensa (em tokens por bloco por token em staking)
    uint256 public rewardRate = 100;
 
    // Último bloco em qye as recompensas foram calculadas 
    uint256 public lastUpdateBlock;

    // Recompensa acumulada por token
    uint256 public rewardPerTokenStored;

    // Total de tokens em stakings
    uint256 public totalStaked;

    // Mapeamento de recompensas por usuário
    mapping (address => uint256) public userRewardPerTokenPaid;
    mapping (address => uint256) public rewards;

    // Mapeamento de saldo de staking por usuário
    mapping(address => uint256) public balances;


    // Eventos
    event Staked (address indexed user, uint256 amount);
    event Withdrawn (address indexed user, uint256 amount);
    event RewardPaid (address indexed user, uint256 reward);

    constructor(address _stakingToken) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
    }

    // Atualiza o estado de recompensa para um usuário específico
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateBlock = block.number;

        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    // Calcula a recompensa por token
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0){return rewardPerTokenStored;}

        return rewardPerTokenStored + (
            ((block.number - lastUpdateBlock) * rewardRate * 1e18) / totalStaked
        );
        
    }

     function earned(address account) public view returns (uint256) {
        return (
            (balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18
        ) + rewards[account];
    }

    function stake(uint256 _amount) external nonReentrant updateReward(msg.sender) {
       require(_amount > 0, "Cannot stake 0");

       totalStaked += _amount;
       balances[msg.sender] += _amount;
         

         // Transfere tokens do usuário para o contrato
        bool success = stakingToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "Token transfer failed");

       emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external nonReentrant updateReward(msg.sender) {
         require(_amount > 0, "Cannot withdraw 0");
         require(balances[msg.sender] >= _amount,"Insufficient staked balance");

       totalStaked -= _amount;
       balances[msg.sender] -= _amount;
       
        // Transfere tokens de volta para o usuário
       bool success = stakingToken.transfer(msg.sender, _amount);
        require(success, "Token transfer failed");

       emit Withdrawn(msg.sender, _amount);
    }


    function getReward() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;

            bool success = stakingToken.transfer(msg.sender, reward);
            require(success, "Token transfer failed");

            emit RewardPaid(msg.sender, reward);
        }
    }
}