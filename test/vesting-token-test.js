const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VestingToken", function () {
  let vestingToken;
  beforeEach(async () => {
    const VestingToken = await ethers.getContractFactory("VestingToken");
    vestingToken = await VestingToken.deploy();
    await vestingToken.deployed();
    [owner, addr1, addr2] = await ethers.getSigners();
    adminRole = await vestingToken.ADMIN_ROLE();
  });

  it("The initial supply must be 1000000", async function () {
    expect(await vestingToken.initialSupply()).to.equal('1000000000000000000000000');
  });

  it("Angel Investors max amount is 40% of initial supply", async function () {
    expect(await vestingToken.hasRole(adminRole, owner.address)).to.equal(true);
    await vestingToken.addVestingSchedule(0, addr1.address, ethers.utils.parseUnits("100000", 18), 0)
    expect(vestingToken.addVestingSchedule(0, addr2.address, ethers.utils.parseUnits("300001", 18), 0)).to.be.revertedWith('limit reached');
  });

  it("Private sale max amount is 30% of initial supply", async function () {
    expect(await vestingToken.hasRole(adminRole, owner.address)).to.equal(true);
    await vestingToken.addVestingSchedule(1, addr1.address, ethers.utils.parseUnits("300000", 18), 0)
    expect(vestingToken.addVestingSchedule(1, addr2.address, ethers.utils.parseUnits("1", 18), 0)).to.be.revertedWith('limit reached');
  });

  it("Public sale max amount is 30% of initial supply", async function () {
    expect(await vestingToken.hasRole(adminRole, owner.address)).to.equal(true);
    await vestingToken.addVestingSchedule(2, addr1.address, ethers.utils.parseUnits("200000", 18), 0)
    expect(vestingToken.addVestingSchedule(2, addr2.address, ethers.utils.parseUnits("200000", 18), 0)).to.be.revertedWith('limit reached');
  });
});
