// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/NFTRegistry.sol";
import "../src/DeveloperSplitter.sol";

interface IxenNFTContract {
    function walletOfOwner(address user) external view returns (uint256[] memory);
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract NFTRegistryTest is Test {
    NFTRegistry public nftRegistry;
    DeveloperSplitter public devSplit;
    IxenNFTContract public nftContract;
    address public nftContractAddress = 0x22c3f74d4AA7c7e11A7637d589026aa85c7AF88a; 
    address public nftFactoryAddress = 0xA06735da049041eb523Ccf0b8c3fB9D36216c646;
    uint256 public initialBalance = 1 ether;

    function setUp() public {
        nftContract = IxenNFTContract(nftContractAddress);
        nftRegistry = new NFTRegistry(nftContractAddress, nftFactoryAddress, address(5));

        console.log("Setup complete.");
    }

    function NFTowner(uint256 _IdNumber) internal view returns (address) {
        address holder;

        try IxenNFTContract(0x22c3f74d4AA7c7e11A7637d589026aa85c7AF88a).ownerOf(_IdNumber) returns (address result) {
            holder = result;
            //console.log("holder", holder, "   Id number ", _IdNumber);
        } catch Error(string memory errorMessage) {
            console.log("Error:", errorMessage);
        } 

        return holder; 
    }

    function NFTRegistration(uint256 _IdNumber) internal {
        address holder;
        address currentLeader = nftRegistry.pointLeader();
        holder = NFTowner((_IdNumber));
        uint fee = nftRegistry.getPointsFee(_IdNumber);
        vm.deal(holder, fee);

        vm.startPrank(holder);

        try nftRegistry.registerNFT{value: fee}(_IdNumber) {}
        catch Error(string memory reason) {
            console.log("Error on nft register:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on nft register");
        }

        assertEq(holder, nftRegistry.getNFTOwner(_IdNumber));
        address postLeader = nftRegistry.pointLeader();
        if (currentLeader != postLeader){
            console.log("New Points Leader", postLeader); 
            uint256 NewHighPoints = nftRegistry.getTotalPointsForUserNFTs(postLeader);
            console.log("New High Points", NewHighPoints);
        }
        console.log("Points registered", nftRegistry.getTokenWeight(_IdNumber));
        console.log("contract balance", address(nftRegistry).balance);
        pointsState();
        console.log("");

        
    }

    function addETH(uint256 _amount) internal {
        vm.deal(address(10), _amount);
        vm.prank(address(10));

        nftRegistry.addToPool{value: _amount}();

        console.log("Eth added to the pool: ", _amount);
    }

    function userPendingRewards(address _user) internal view returns (uint256){
        uint256 pendingRewards = nftRegistry.getPendingReward(_user);
        return pendingRewards;
    }

    function pointsState() internal view {
        uint256 TPoints;
        TPoints = nftRegistry.totalPoints();
        console.log("current Total Points: ", TPoints);
    }

    
    function testNFTRegistration() public {
        pointsState();
        NFTRegistration(13);
    }

    function testNFTRegistrationMany() public {
        pointsState();
        NFTRegistration(13);
        NFTRegistration(19);
        NFTRegistration(123);
        NFTRegistration(139);
        NFTRegistration(243);
        
        NFTRegistration(313);
        NFTRegistration(453);
        NFTRegistration(513);
    }

    function testRandomNFTRegistration() public {
        pointsState();
        uint256 maxID = 50;
        uint totalPoints = 0;
        
        for (uint256 tokenId = 1; tokenId <= maxID; tokenId++) {
            NFTRegistration(tokenId);
            uint weight = nftRegistry.getTokenWeight(tokenId);
            console.log("token Id:", tokenId, "token points: ", weight);
            totalPoints += weight;
        }

        console.log(" ");
        console.log(" ------------------------------------------------- ");
        console.log("total nfts ", maxID, "     total Points ", totalPoints);
        console.log("contract balance", address(nftRegistry).balance );
    }

    function testAllPointsRegistration() public {
        pointsState();
        uint256 maxID = 20;
        uint totalPoints = 0;

        
        console.log("Token ID   |   Token Points");

        for (uint256 tokenId = 1; tokenId <= maxID; tokenId++) {
            
            uint weight = nftRegistry.getTokenWeight(tokenId);
            
            console.log(formatTableRow(tokenId, weight));

            totalPoints += weight;
        }

        console.log(" ");
        console.log(" ------------------------------------------------- ");
        console.log("total nfts ", maxID, "     total Points ", totalPoints);
        console.log("contract balance", address(nftRegistry).balance);
    }

    function formatTableRow(uint256 tokenId, uint weight) internal pure returns (string memory) {
        // Convert uint to string
        string memory tokenIdStr = uintToString(tokenId);
        string memory weightStr = uintToString(weight);

        

        // Concatenate strings with padding
        return string(abi.encodePacked(tokenIdStr, " " , " " , " " , " " , " " , " " , " " , " " , " " , " " , " " , " " , "|", weightStr));
    }

    function uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function testUserRewardsTracking() public {
         NFTRegistration(13);
        NFTRegistration(19);
        NFTRegistration(123);
        NFTRegistration(139);
        NFTRegistration(243);
        
        NFTRegistration(313);
        NFTRegistration(453);
        NFTRegistration(513);

        console.log("");
        console.log("user:", NFTowner(313) , "rewards", nftRegistry.getPendingReward(NFTowner(313)));
        console.log ("user:", NFTowner(313) ,  "total Points", nftRegistry.getTotalPointsForUserNFTs(NFTowner(313)));
        console.log("");
        console.log("user:", NFTowner(123) , "rewards", nftRegistry.getPendingReward(NFTowner(123)));
        console.log ("user:", NFTowner(123) ,  "total Points", nftRegistry.getTotalPointsForUserNFTs(NFTowner(123)));
        console.log("");

        addETH(1 ether);

        console.log("user:", NFTowner(313) , "rewards", nftRegistry.getPendingReward(NFTowner(313)));
        console.log ("user:", NFTowner(313) ,  "total Points", nftRegistry.getTotalPointsForUserNFTs(NFTowner(313)));
        console.log("");
        console.log("user:", NFTowner(123) , "rewards", nftRegistry.getPendingReward(NFTowner(123)));
        console.log ("user:", NFTowner(123) ,  "total Points", nftRegistry.getTotalPointsForUserNFTs(NFTowner(123)));
        console.log("");
    
    }

    function testUserWithdraw() public {
        testUserRewardsTracking();

        console.log("Initial data:");
        uint256 user1Rewards = nftRegistry.getPendingReward(NFTowner(313));
        uint256 user1Balance = address(NFTowner(313)).balance;
        uint256 user2Rewards = nftRegistry.getPendingReward(NFTowner(123));
        uint256 user2Balance = address(NFTowner(123)).balance;

        console.log("User 1 - Rewards: ", user1Rewards, " Balance before withdrawal: ", user1Balance);
        console.log("User 2 - Rewards: ", user2Rewards, " Balance before withdrawal: ", user2Balance);

        assertGt(user1Rewards, 0);
        assertGt(user2Rewards, 0);

        vm.prank(NFTowner(313));
        console.log("User 1 pranked.");

        nftRegistry.withdrawRewards();
        console.log("User 1 withdrew rewards.");

        uint256 user1RewardsAfter = nftRegistry.getPendingReward(NFTowner(313));
        uint256 user1BalanceAfter = address(NFTowner(313)).balance;

        console.log("User 1 - Rewards after withdrawal: ", user1RewardsAfter);
        console.log("User 1 - Balance after withdrawal: ", user1BalanceAfter);

        assertEq(user1RewardsAfter, 0);
        assertGt(user1BalanceAfter, user1Balance);
        console.log("Difference in balance for User 1: ", user1BalanceAfter - user1Balance);

        vm.prank(NFTowner(123));
        console.log("User 2 pranked.");

        nftRegistry.withdrawRewards();
        
        console.log("User 2 withdrew rewards.");

        uint256 user2RewardsAfter = nftRegistry.getPendingReward(NFTowner(123));
        uint256 user2BalanceAfter = address(NFTowner(123)).balance;

        console.log("User 2 - Rewards after withdrawal: ", user2RewardsAfter);
        console.log("User 2 - Balance after withdrawal: ", user2BalanceAfter);

        assertEq(user2RewardsAfter, 0);
        assertGt(user2BalanceAfter, user2Balance);
        console.log("Difference in balance for User 2: ", user2BalanceAfter - user2Balance);
    }

    function testFailNftRegistration() public {
        vm.prank(address(10));
        try nftRegistry.registerNFT(42) {}
        catch Error(string memory reason) {
            console.log("Error on nft register:", reason);
        } catch (bytes memory) /*lowLevelData*/ {
            console.log("Low level error on nft register");
        }

        assertEq(address(10), nftRegistry.getNFTOwner(42));
    }

    function testFailNftRegistrationtwice() public {
        NFTRegistration(243);
        NFTRegistration(243);
        

        assertGt(nftRegistry.getTotalPointsForUserNFTs(NFTowner(243)), nftRegistry.getTokenWeight(243));
    }
    
    function testFailUserWithdraw() public {
        testUserRewardsTracking();

        console.log("Initial data:");
        uint256 user1Rewards = nftRegistry.getPendingReward(NFTowner(313));
        uint256 user1Balance = address(NFTowner(313)).balance;
        uint256 user2Rewards = nftRegistry.getPendingReward(NFTowner(123));
        uint256 user2Balance = address(NFTowner(123)).balance;

        console.log("User 1 - Rewards: ", user1Rewards, " Balance before withdrawal: ", user1Balance);
        console.log("User 2 - Rewards: ", user2Rewards, " Balance before withdrawal: ", user2Balance);

        assertGt(user1Rewards, 0);
        assertGt(user2Rewards, 0);

        vm.prank(NFTowner(313));
        console.log("User 1 pranked.");

        nftRegistry.withdrawRewards();
        console.log("User 1 withdrew rewards.");

        uint256 user1RewardsAfter = nftRegistry.getPendingReward(NFTowner(313));
        uint256 user1BalanceAfter = address(NFTowner(313)).balance;

        console.log("User 1 - Rewards after withdrawal: ", user1RewardsAfter);
        console.log("User 1 - Balance after withdrawal: ", user1BalanceAfter);

        assertEq(user1RewardsAfter, 0);
        assertGt(user1BalanceAfter, user1Balance);
        console.log("Difference in balance for User 1: ", user1BalanceAfter - user1Balance);

        vm.prank(NFTowner(123));
        console.log("User 2 pranked.");

        nftRegistry.withdrawRewards();
        nftRegistry.withdrawRewards();
        console.log("User 2 withdrew rewards.");

        uint256 user2RewardsAfter = nftRegistry.getPendingReward(NFTowner(123));
        uint256 user2BalanceAfter = address(NFTowner(123)).balance;

        console.log("User 2 - Rewards after withdrawal: ", user2RewardsAfter);
        console.log("User 2 - Balance after withdrawal: ", user2BalanceAfter);

        assertEq(user2RewardsAfter, 0);
        assertGt(user2BalanceAfter, user2Balance);
        console.log("Difference in balance for User 2: ", user2BalanceAfter - user2Balance);
    }

    function testPointsLeaderChange() public {
        pointsState();
        
        address initialLeader = nftRegistry.pointLeader();
        uint256 initialHighPoints = nftRegistry.getTotalPointsForUserNFTs(initialLeader);
        console.log("Initial Points Leader: ", initialLeader);
        console.log("Initial High Points: ", initialHighPoints);

        NFTRegistration(13);
        
        address newLeader = nftRegistry.pointLeader();
        uint256 newHighPoints = nftRegistry.getTotalPointsForUserNFTs(newLeader);
        console.log("New Points Leader: ", newLeader);
        console.log("New High Points: ", newHighPoints);

        assertNotEq(initialLeader, newLeader, "Points leader should have changed");
        assertGt(newHighPoints, initialHighPoints, "New leader should have higher points");
    }

    function testMoreWithdrawalScenarios() public {
        pointsState();

        NFTRegistration(313);
        NFTRegistration(19);
        addETH(2 ether);
        NFTRegistration(123);
        NFTRegistration(139);
        addETH(4 ether);
        NFTRegistration(243);

        console.log("Initial data:");
        console.log("player points", nftRegistry.getTotalPointsForUserNFTs(NFTowner(313)));
        uint256 user1Rewards = nftRegistry.getPendingReward(NFTowner(313));
        uint256 user1Balance = address(NFTowner(313)).balance;
        uint256 user2Rewards = nftRegistry.getPendingReward(NFTowner(123));
        uint256 user2Balance = address(NFTowner(123)).balance;

        console.log("User 1 - Rewards: ", user1Rewards, " Balance before withdrawal: ", user1Balance);
        console.log("User 2 - Rewards: ", user2Rewards, " Balance before withdrawal: ", user2Balance);

        assertGt(user1Rewards, 0);
        assertGt(user2Rewards, 0);

        vm.prank(NFTowner(313));
        console.log("User 1 pranked.");

        nftRegistry.withdrawRewards();
        console.log("User 1 withdrew rewards.");

        uint256 user1RewardsAfter = nftRegistry.getPendingReward(NFTowner(313));
        uint256 user1BalanceAfter = address(NFTowner(313)).balance;

        console.log("User 1 - Rewards after withdrawal: ", user1RewardsAfter);
        console.log("User 1 - Balance after withdrawal: ", user1BalanceAfter);
        console.log("Difference in balance for User 1: ", user1BalanceAfter - user1Balance);

        vm.prank(NFTowner(123));
        console.log("User 2 pranked.");

        nftRegistry.withdrawRewards();
        console.log("User 2 withdrew rewards.");

        uint256 user2RewardsAfter = nftRegistry.getPendingReward(NFTowner(123));
        uint256 user2BalanceAfter = address(NFTowner(123)).balance;

        console.log("User 2 - Rewards after withdrawal: ", user2RewardsAfter);
        console.log("User 2 - Balance after withdrawal: ", user2BalanceAfter);
        console.log("Difference in balance for User 2: ", user2BalanceAfter - user2Balance);

        NFTRegistration(319);
        NFTRegistration(190);
        addETH(1 ether);
        NFTRegistration(129);
        NFTRegistration(199);
        addETH(2 ether);
        NFTRegistration(277);

        console.log("player points", nftRegistry.getTotalPointsForUserNFTs(NFTowner(313)));
        user1Rewards = nftRegistry.getPendingReward(NFTowner(313));
        user1Balance = address(NFTowner(313)).balance;
        user2Rewards = nftRegistry.getPendingReward(NFTowner(123));
        user2Balance = address(NFTowner(123)).balance;

        console.log("User 1 - Rewards: ", user1Rewards, " Balance before withdrawal: ", user1Balance);
        console.log("User 2 - Rewards: ", user2Rewards, " Balance before withdrawal: ", user2Balance);

        assertGt(user1Rewards, 0);
        assertGt(user2Rewards, 0);

        vm.prank(NFTowner(313));
        console.log("User 1 pranked.");

        nftRegistry.withdrawRewards();
        console.log("User 1 withdrew rewards.");

        user1RewardsAfter = nftRegistry.getPendingReward(NFTowner(313));
        user1BalanceAfter = address(NFTowner(313)).balance;

        console.log("User 1 - Rewards after withdrawal: ", user1RewardsAfter);
        console.log("User 1 - Balance after withdrawal: ", user1BalanceAfter);
        console.log("Difference in balance for User 1: ", user1BalanceAfter - user1Balance);

        vm.prank(NFTowner(123));
        console.log("User 2 pranked.");

        nftRegistry.withdrawRewards();
        console.log("User 2 withdrew rewards.");

        user2RewardsAfter = nftRegistry.getPendingReward(NFTowner(123));
        user2BalanceAfter = address(NFTowner(123)).balance;

        console.log("User 2 - Rewards after withdrawal: ", user2RewardsAfter);
        console.log("User 2 - Balance after withdrawal: ", user2BalanceAfter);
        console.log("Difference in balance for User 2: ", user2BalanceAfter - user2Balance);
    }
}
