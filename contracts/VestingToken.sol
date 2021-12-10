//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./files/ERC20.sol";

contract VestingToken is ERC20 {
    uint256 public initialSupply = 1_000_000 * 10 ** 18;
    address public burnAddress;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(bytes32 => mapping(address=>bool)) private _roles;
    /**Vesting type */
    struct VestingType {
      string name;
      uint64 cliffDuration;
      uint64 vestingDuration;
      uint32 totalPercent;
      uint256 currentAmount;
    }

    VestingType[] public vestingTypes;
    
    /**Vesting schedule */
    struct VestingSchedule {
      uint64 startVestingTimestamp;
      uint256 amount;
      uint32 vestingTypeIndex;
      uint256 claimedTokens;
    }

    mapping(address => VestingSchedule) private _vestingSchedules;

    constructor() ERC20("TUNG NGUYEN", "TNT") {
        _grantRole(ADMIN_ROLE,msg.sender);
        burnAddress = msg.sender;
        vestingTypes.push(VestingType("ANGEL_INVESTORS", 60 * 60 * 24 * 7, 60 * 60 * 24 * 30, 40, 0));
        vestingTypes.push(VestingType("PRIVATE_SALE", 60 * 60 * 24 * 3, 60 * 60 * 24 * 1, 30, 0));
        vestingTypes.push(VestingType("PUBLIC_SALE", 0, 0, 30, 0));
        /** below code is for testing online*/
        // vestingTypes.push(VestingType("ANGEL_INVESTORS", 60, 60 * 60 * 24 * 30, 40, 0));
        // vestingTypes.push(VestingType("PRIVATE_SALE", 60, 60 * 60 * 24 * 1, 30, 0));
        // vestingTypes.push(VestingType("PUBLIC_SALE", 0, 0, 30, 0));
    }

    modifier onlyRole(bytes32 role) {
        require(hasRole(role,msg.sender),"Not Authorized!");
        _;
    }

    function grantRole(bytes32 role, address account) private onlyRole(ADMIN_ROLE) {
        _grantRole(role, account);
    }

    function _grantRole(bytes32 role, address account) private {
        _roles[role][account] = true;
    }

    function revokeRole(bytes32 role, address account) private onlyRole(ADMIN_ROLE) {
        _roles[role][account] = false;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    function burn(uint256 amount) public{
        _transfer(msg.sender, burnAddress, amount);
    }

    function getVestingSchedule(address account) public view onlyRole(ADMIN_ROLE) returns (string memory name, uint256 currentAmount, uint64 vestingDuration, uint64 startVestingTimestamp) {
        return (vestingTypes[_vestingSchedules[account].vestingTypeIndex].name, vestingTypes[_vestingSchedules[account].vestingTypeIndex].currentAmount, vestingTypes[_vestingSchedules[account].vestingTypeIndex].vestingDuration, _vestingSchedules[account].startVestingTimestamp);
    }

    function currentTime() public view returns (uint64) {
        return uint64(block.timestamp);
    }

    function addVestingSchedule(uint32 vestingTypeIndex, address account, uint256 amount, uint64 startTime) public onlyRole(ADMIN_ROLE) {
        require(vestingTypeIndex >= 0 && vestingTypeIndex <= vestingTypes.length, "index is not valid");
        require(vestingTypes[vestingTypeIndex].currentAmount + amount <= initialSupply * vestingTypes[vestingTypeIndex].totalPercent/100, "limit reached");
        require(_vestingSchedules[account].startVestingTimestamp == 0 || _vestingSchedules[account].amount == 0 || block.timestamp > _vestingSchedules[account].startVestingTimestamp + vestingTypes[vestingTypeIndex].vestingDuration, "already has schedule");
        //calculate start vesting timestamp
        if (startTime != 0) {
            startTime += vestingTypes[vestingTypeIndex].cliffDuration;
        } else {
            startTime = uint64(block.timestamp) + vestingTypes[vestingTypeIndex].cliffDuration;
        }
        _vestingSchedules[account] = VestingSchedule(startTime, amount, vestingTypeIndex, 0);
        vestingTypes[vestingTypeIndex].currentAmount += amount;
    }

    function claimTokens() public {
        uint256 claimableTokens = claimable();
        _vestingSchedules[msg.sender].claimedTokens += claimableTokens;
        _vestingSchedules[msg.sender].amount -= claimableTokens;
        _mint(msg.sender, claimableTokens);
    }

    function claimable() public view returns(uint256) {
        return unlockedAmount() - claimedTokens();
    }

    function claimedTokens() public view returns (uint256) {
        return _vestingSchedules[msg.sender].claimedTokens;
    }

    function grantedAmount() public view returns (uint256) {
        return _vestingSchedules[msg.sender].amount +  claimedTokens();
    }

    function lockedAmount() public view returns (uint256) {
        uint256 totalAllocation = _vestingSchedules[msg.sender].amount +  claimedTokens();
        if (block.timestamp < _vestingSchedules[msg.sender].startVestingTimestamp) {
            return _vestingSchedules[msg.sender].amount;
        } else if (block.timestamp > _vestingSchedules[msg.sender].startVestingTimestamp + vestingTypes[_vestingSchedules[msg.sender].vestingTypeIndex].vestingDuration) {
            return 0;
        } else {
            return totalAllocation - unlockedAmount();
        }
    }

    function unlockedAmount() public view returns (uint256) {
        uint256 totalAllocation = _vestingSchedules[msg.sender].amount +  claimedTokens();
        if (block.timestamp < _vestingSchedules[msg.sender].startVestingTimestamp) {
            return 0;
        } else if (block.timestamp > _vestingSchedules[msg.sender].startVestingTimestamp + vestingTypes[_vestingSchedules[msg.sender].vestingTypeIndex].vestingDuration) {
            return totalAllocation;
        } else {
            return (totalAllocation * (block.timestamp - _vestingSchedules[msg.sender].startVestingTimestamp)) / vestingTypes[_vestingSchedules[msg.sender].vestingTypeIndex].vestingDuration;
        }
    }

    /**Returns unlocked amount of a time. eg: 1639111376 (Fri Dec 10 2021 11:42:56 GMT+0700) */
    function unlockedAmountWithTimestamp(uint64 timestamp) public view returns (uint256) {
        uint256 totalAllocation = _vestingSchedules[msg.sender].amount +  claimedTokens();
        if (timestamp < _vestingSchedules[msg.sender].startVestingTimestamp) {
            return 0;
        } else if (timestamp > _vestingSchedules[msg.sender].startVestingTimestamp + vestingTypes[_vestingSchedules[msg.sender].vestingTypeIndex].vestingDuration) {
            return totalAllocation;
        } else {
            return (totalAllocation * (timestamp - _vestingSchedules[msg.sender].startVestingTimestamp)) / vestingTypes[_vestingSchedules[msg.sender].vestingTypeIndex].vestingDuration;
        }
    }
}