// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IXENNFTContract {
    function ownerOf(uint256) external view returns (address);
}

interface IXENNFTfactory {
    function baseDBXeNFTPower(uint256) external view returns (uint256);
}

contract NFTRegistry {
    struct NFT {
        uint256 tokenId;
        
    }

    struct User {
        NFT[] userNFTs;
        uint256 userRewards; // Tracks total rewards sent to user.
        uint256 userPoints;
        uint256 lastRewardRatio;
        uint256 leaderReward;
    }

    mapping(address => User) public users;
    
    mapping(uint256 => address) public currentHolder;
       
    

    address public nftContractAddress;
    address public nftFactoryAddress;
    address public devAddress;
    address public pointLeader; 
    uint256 public totalRewards;
    uint256 public totalPoints;
    uint256 public rewardRatio;
    uint256 public leaderTotalPoints;
    uint256 public constant pointsFee = 0.00125 ether; 

    
    constructor(address _nftContractAddress, address _nftFactoryAddress, address _devAddress) {
        nftContractAddress = _nftContractAddress;
        nftFactoryAddress = _nftFactoryAddress;
        devAddress = _devAddress; 

        // Initialize totalRewards and totalPoints with small non-zero values
        totalRewards = 1; 
        totalPoints = 1;
        leaderTotalPoints = 1; 
    }

    event NFTRegistered(address indexed user, uint256 tokenId, uint256 rewards);
    event RewardsWithdrawn(address indexed user, uint256 amount);
    event newPointsLeader(address indexed user, uint256 amount);
    
    modifier transferFee() {
        _;
        uint256 poolShare = (msg.value * 250) / 1000;
        rewardRatio += poolShare / totalPoints;
        uint256 devShare = msg.value - poolShare; 
        payable(devAddress).transfer(devShare);

    }

    modifier hasSufficientFee(uint _tokenId) {
        require(msg.value >= getPointsFee(_tokenId), "Insufficient fee");
        _;
    }
    receive() external payable {
        // Split msg.value 50% to rewardRatio and 50% to pointLeader
        uint256 halfValue = msg.value / 2;
        rewardRatio += halfValue / totalPoints;
        users[pointLeader].leaderReward += halfValue;
        totalRewards += msg.value;
    }

    function addToPool() external payable {
        // Split msg.value 50% to rewardRatio and 50% to pointLeader
        uint256 halfValue = msg.value / 2;
        rewardRatio += (halfValue / totalPoints);
        users[pointLeader].leaderReward += halfValue;
        totalRewards += msg.value;
    }

    function registerNFT(uint256 tokenId) public payable hasSufficientFee(tokenId) transferFee {
        address player = msg.sender;
        require(IXENNFTContract(nftContractAddress).ownerOf(tokenId) == player, "You don't own this NFT.");

        // Calculate the reward points for the NFT
        uint256 rewardPoints = getTokenWeight(tokenId);

        // Check if the NFT was previously registered to a different user
        address  previousOwner = getNFTOwner(tokenId);
        require(previousOwner != player, "You already have this NFT regestered");
        if (previousOwner != address(0) && previousOwner != player) {
            User storage previousOwnerData = users[previousOwner];
            
            uint256 previousRewardAmount = calculateReward(previousOwner);
            address payable previousOwnerpay = payable(previousOwner);
            
            // Remove the previous owner's points            
            previousOwnerData.userPoints -= rewardPoints;
            totalPoints -= rewardPoints;
            previousOwnerData.userRewards += previousRewardAmount;
            previousOwnerData.lastRewardRatio = rewardRatio;
            
            // Remove the NFT from the previous owner's list
            for (uint256 i = 0; i < previousOwnerData.userNFTs.length; i++) {
                if (previousOwnerData.userNFTs[i].tokenId == tokenId) {
                    // Shift all elements to the left
                    for (uint256 j = i; j < previousOwnerData.userNFTs.length - 1; j++) {
                        previousOwnerData.userNFTs[j] = previousOwnerData.userNFTs[j + 1];
                    }
                    // Remove the last element
                    previousOwnerData.userNFTs.pop();
                    break;
                }
            }
            
            // Pay the previous owner their rewards
            previousOwnerpay.transfer(previousRewardAmount);

        }
        User storage currentUserData = users[player];

        if (currentUserData.lastRewardRatio != rewardRatio && currentUserData.lastRewardRatio != 0) {
            withdrawRewards();
        }

        // Update the user's rewards, points, and last rewarded timestamp

        currentUserData.userPoints += rewardPoints;
        totalPoints += rewardPoints;
        currentUserData.lastRewardRatio = rewardRatio;

        // Update the NFT ownership
        setNFTOwner(tokenId, player);

        // check for points leader 

        if (currentUserData.userPoints > leaderTotalPoints) {
            pointLeader = player; 
            leaderTotalPoints = currentUserData.userPoints;

            emit newPointsLeader(player, currentUserData.userPoints);
        }

        emit NFTRegistered(player, tokenId, rewardPoints);
    }

    function registerNFTs(uint256[] memory tokenIds) external {
        uint len = tokenIds.length;
            for (uint256 i = 0; i < len; i++) {
                registerNFT(tokenIds[i]);
            }
    }
    

    function isNFTRegistered(uint256 tokenId) public view returns (bool) {
        address player = msg.sender;
        NFT[] storage userNFTs = users[player].userNFTs;
        uint len = userNFTs.length;
        for (uint256 j = 0; j < len; j++) {
            if (userNFTs[j].tokenId == tokenId) {
                return true;
            }
        }
        return false;
    }

    function setNFTOwner(uint256 tokenId, address owner) private {
        require(currentHolder[tokenId] != owner, "NFT already registered by the caller.");

        
        currentHolder[tokenId] = owner;

        // Add the token ID to the user's NFTs
        users[owner].userNFTs.push(NFT(tokenId));
    }

    function getNFTOwner(uint256 tokenId) public view returns (address) {
        return currentHolder[tokenId];
    }

    
    function calculateReward(address user) public view returns (uint256) {
        User storage userData = users[user];
        uint256 lastRewardRatio = userData.lastRewardRatio;
        uint256 newRewards = rewardRatio - lastRewardRatio;
        uint256 reward = newRewards * userData.userPoints;

        
        return reward;
    }

    function withdrawRewards() public payable {
        address player = msg.sender;
        User storage userData = users[player];
        require(userData.userPoints > 0, "No XenFT's registered for this user");

        
        if (!_hasValidOwnership(player)) {
    for (uint256 i = 0; i < userData.userNFTs.length; i++) {
        if(!_isNFTOwner(userData.userNFTs[i].tokenId, player)) {
                    // remove points for this NFT
                    userData.userPoints -= getTokenWeight(userData.userNFTs[i].tokenId);
                    setNFTOwner(userData.userNFTs[i].tokenId, address(0));
                    // remove NFT from user's list
                    for (uint256 j = i; j < userData.userNFTs.length - 1; j++) {
                        userData.userNFTs[j] = userData.userNFTs[j + 1];
                    }
                    userData.userNFTs.pop();
                    // decrease i to rerun the check for the NFT that was shifted from the right
                    i--;
                }
            }
        }

        uint256 rewardAmount = calculateReward(player);
        rewardAmount += userData.leaderReward;
        userData.leaderReward = 0;

        require(rewardAmount > 0, "No new rewards available for withdrawal.");

        // Effects
        userData.userRewards += rewardAmount;
        userData.lastRewardRatio = rewardRatio;

        // Interactions
        payable(player).transfer(TransferOutAmount(rewardAmount));
        emit RewardsWithdrawn(player, rewardAmount);
    }

    function _isNFTOwner(uint256 tokenId, address owner) public view returns (bool) {
        IXENNFTContract nftContract = IXENNFTContract(nftContractAddress);
        address nftOwner = nftContract.ownerOf(tokenId);

        return nftOwner == owner;
    }

    
    function getTokenWeight(uint256 tokenId) public view returns (uint256) {
        uint points = IXENNFTfactory(nftFactoryAddress).baseDBXeNFTPower(tokenId) / 1 ether; 

        return points;
    }

    function getTotalPointsForUserNFTs(address userAddress) public view returns (uint256) {
        uint256 usertotalPoints = 0;
        User storage user = users[userAddress];

        for (uint256 i = 0; i < user.userNFTs.length; i++) {
            uint256 tokenId = user.userNFTs[i].tokenId;
            uint256 points = getTokenWeight(tokenId); // You can define the getTokenWeight function
            usertotalPoints += points;
        }

        return usertotalPoints;
    }

    function getPendingReward(address user) public view returns (uint256) {
        User storage userData = users[user];
        uint256 lastRewardRatio = userData.lastRewardRatio;
        uint256 newRewards = rewardRatio - lastRewardRatio;
        uint256 reward = newRewards * userData.userPoints;
        reward += userData.leaderReward;
        
        return reward;
    }

    function getPointsFee(uint _tokenId) public view returns (uint256){
        uint256 points = getTokenWeight(_tokenId);
        uint256 fee = points * pointsFee;

        return fee;

    }

    function _hasValidOwnership(address user) public view returns (bool) {
        User storage userData = users[user];
        uint256 totalPointsOwned = 0;
        uint len = userData.userNFTs.length;
        for (uint256 i = 0; i < len; i++) {
            NFT storage nft = userData.userNFTs[i];
            if (_isNFTOwner(nft.tokenId, user)) {
                totalPointsOwned += getTokenWeight(nft.tokenId);
            } else {
                return false;
            }
        }

        return totalPointsOwned == userData.userPoints;
    }

    function TransferOutAmount(uint256 _amount) internal returns (uint256){
        uint _Fee = (_amount * 259) / 10000;
        payable(devAddress).transfer(_Fee);
        return _amount - _Fee;
    }
}
