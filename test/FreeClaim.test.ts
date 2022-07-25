import { expect } from "chai";
import { ethers } from "hardhat";
import log from "ololog";

import { MaxxFinance } from "../typechain-types/contracts/MaxxFinance";
import { MaxxFinance__factory } from "../typechain-types/factories/contracts/MaxxFinance__factory";

import { MaxxStake } from "../typechain-types/contracts/MaxxStake";
import { MaxxStake__factory } from "../typechain-types/factories/contracts/MaxxStake__factory";

import { FreeClaim } from "../typechain-types/contracts/FreeClaim";
import { FreeClaim__factory } from "../typechain-types/factories/contracts/FreeClaim__factory";

describe("Free Claim", () => {
  let Maxx: MaxxFinance__factory;
  let maxx: MaxxFinance;

  let Stake: MaxxStake__factory;
  let stake: MaxxStake;

  let FreeClaim: FreeClaim__factory;
  let freeClaim: FreeClaim;

  let stakeLaunchDate: any;
  const nftAddress: any = "0x0000000000000000000000000000000000000000"; // TODO add real address

  let startDate: any;
  const merkleRoot: any =
    "0xc7679223c0cf31f46222fcdd829c232851d4102b198f7b0ee30a218300a0ccbe"; // TODO add real merkle root

  const maxxVault = "0xBF7BF3d445aEc7B0c357163d5594DB8ca7C12D31";

  let signers: any;
  let deployer: any;

  before(async () => {
    signers = await ethers.getSigners();
    deployer = signers[0];
    Maxx = (await ethers.getContractFactory(
      "MaxxFinance"
    )) as MaxxFinance__factory;
    maxx = await Maxx.deploy(deployer.address, 500, 1000000, 1000000000); // 5% transfer tax, 1M whaleLimit, 1B globalDailySellLimit

    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;
    stakeLaunchDate = timestampBefore + 1;

    Stake = (await ethers.getContractFactory(
      "MaxxStake"
    )) as MaxxStake__factory;
    stake = await Stake.deploy(
      maxxVault,
      maxx.address,
      stakeLaunchDate,
      nftAddress
    );

    startDate = stakeLaunchDate + 1;

    FreeClaim = (await ethers.getContractFactory(
      "FreeClaim"
    )) as FreeClaim__factory;
    freeClaim = await FreeClaim.deploy(startDate, merkleRoot, maxx.address);
  });

  describe("deploy", () => {
    it("should deploy", async () => {
      expect(maxx.address).to.exist;
      expect(stake.address).to.exist;
      expect(freeClaim.address).to.exist;
    });
  });

  describe("Claim", () => {
    it("should verify the merkle leaf", async () => {
      const amount = 0;
      const proof = [
        "0x11470846972103cbf2c251e83e2499f8fbe25a6424dc17934c81271840db1cef",
        "0xc49b942f9a725fab9c08d4a6252eab55fe71209c11a0a95abe8d11853525c86d",
        "0x9a30aee98573043fb4b9802a4ab110e29be98a0238b09773679485b19504e9dd",
        "0xc3f441f3bbb5fd3a4fe5485361649ed4fcb6f022f81e7dc98bddc3f32e671cd5",
        "0x4923a3cc2b813554de95385210ea6a6e3e2af78a7807a231d1faafa6d11f974e",
        "0x74b1b7afb4fd25cdbf7cdb379c4adf9323651c4202fc6e874a639f585ef46042",
        "0x7f20955ddabef7fcb4299f61d57376fc6cc5c5b85b383f1b783e819ecb6194be",
        "0x805ac5d81bbcb7bc5bcd9a67becb50110d6f42fff19daa2ef3a28a81e6ff3026",
        "0xfe68c295f0a224949a25212893b81c57243f88713750630ec44d2f575b19eb24",
        "0x226bc9ffbb27b2ae8c79a1ed7b9e5b4b68950a89e99dbab6b6e73ca495dcdcb2",
        "0xb9c44b58729edf081e44deecc7ba8cbcf2a223614a73ff33f65fac0eac80dddc",
        "0x27828ab2fbca6afec380839a1e192b5a019bb64503e1929145666356c0d9c4c5",
        "0x950ca4506db91b881ecf335349df03c320952d1ba09e460bbc4f231274a0fbbd",
        "0x385d51367babf27c3fe830d64976e9e9affd29a50ab0d6d2121970a7c02747f1",
        "0xde2d2601929d64613d1c04ef046c041301eae2b39254ea04de5d676d58ae8ed3",
        "0x7c6969261cddab75d971bc975a7fcc0bf38fb09039a8e93038262f8c5ad89467",
      ]; // TODO: add the real proof
      const eligibility = await freeClaim.verifyMerkleLeaf(
        deployer.address,
        amount,
        proof
      );
      expect(eligibility).to.be.true;
    });

    it("should not verify the merkle leaf with an incorrect amount", async () => {
      const amount = 0; // wrong amount
      const proof = [
        "0x11470846972103cbf2c251e83e2499f8fbe25a6424dc17934c81271840db1cef",
        "0xc49b942f9a725fab9c08d4a6252eab55fe71209c11a0a95abe8d11853525c86d",
        "0x9a30aee98573043fb4b9802a4ab110e29be98a0238b09773679485b19504e9dd",
        "0xc3f441f3bbb5fd3a4fe5485361649ed4fcb6f022f81e7dc98bddc3f32e671cd5",
        "0x4923a3cc2b813554de95385210ea6a6e3e2af78a7807a231d1faafa6d11f974e",
        "0x74b1b7afb4fd25cdbf7cdb379c4adf9323651c4202fc6e874a639f585ef46042",
        "0x7f20955ddabef7fcb4299f61d57376fc6cc5c5b85b383f1b783e819ecb6194be",
        "0x805ac5d81bbcb7bc5bcd9a67becb50110d6f42fff19daa2ef3a28a81e6ff3026",
        "0xfe68c295f0a224949a25212893b81c57243f88713750630ec44d2f575b19eb24",
        "0x226bc9ffbb27b2ae8c79a1ed7b9e5b4b68950a89e99dbab6b6e73ca495dcdcb2",
        "0xb9c44b58729edf081e44deecc7ba8cbcf2a223614a73ff33f65fac0eac80dddc",
        "0x27828ab2fbca6afec380839a1e192b5a019bb64503e1929145666356c0d9c4c5",
        "0x950ca4506db91b881ecf335349df03c320952d1ba09e460bbc4f231274a0fbbd",
        "0x385d51367babf27c3fe830d64976e9e9affd29a50ab0d6d2121970a7c02747f1",
        "0xde2d2601929d64613d1c04ef046c041301eae2b39254ea04de5d676d58ae8ed3",
        "0x7c6969261cddab75d971bc975a7fcc0bf38fb09039a8e93038262f8c5ad89467",
      ]; // TODO: add the real proof
      const eligibility = await freeClaim.verifyMerkleLeaf(
        deployer.address,
        amount,
        proof
      );
      expect(eligibility).to.be.false;
    });

    it("should not verify the merkle leaf with an incorrect account", async () => {
      const amount = 0; // wrong amount
      const proof = [
        "0x11470846972103cbf2c251e83e2499f8fbe25a6424dc17934c81271840db1cef",
        "0xc49b942f9a725fab9c08d4a6252eab55fe71209c11a0a95abe8d11853525c86d",
        "0x9a30aee98573043fb4b9802a4ab110e29be98a0238b09773679485b19504e9dd",
        "0xc3f441f3bbb5fd3a4fe5485361649ed4fcb6f022f81e7dc98bddc3f32e671cd5",
        "0x4923a3cc2b813554de95385210ea6a6e3e2af78a7807a231d1faafa6d11f974e",
        "0x74b1b7afb4fd25cdbf7cdb379c4adf9323651c4202fc6e874a639f585ef46042",
        "0x7f20955ddabef7fcb4299f61d57376fc6cc5c5b85b383f1b783e819ecb6194be",
        "0x805ac5d81bbcb7bc5bcd9a67becb50110d6f42fff19daa2ef3a28a81e6ff3026",
        "0xfe68c295f0a224949a25212893b81c57243f88713750630ec44d2f575b19eb24",
        "0x226bc9ffbb27b2ae8c79a1ed7b9e5b4b68950a89e99dbab6b6e73ca495dcdcb2",
        "0xb9c44b58729edf081e44deecc7ba8cbcf2a223614a73ff33f65fac0eac80dddc",
        "0x27828ab2fbca6afec380839a1e192b5a019bb64503e1929145666356c0d9c4c5",
        "0x950ca4506db91b881ecf335349df03c320952d1ba09e460bbc4f231274a0fbbd",
        "0x385d51367babf27c3fe830d64976e9e9affd29a50ab0d6d2121970a7c02747f1",
        "0xde2d2601929d64613d1c04ef046c041301eae2b39254ea04de5d676d58ae8ed3",
        "0x7c6969261cddab75d971bc975a7fcc0bf38fb09039a8e93038262f8c5ad89467",
      ]; // TODO: add the real proof
      const eligibility = await freeClaim.verifyMerkleLeaf(
        signers[3].address,
        amount,
        proof
      );
      expect(eligibility).to.be.false;
    });

    it("should make a free claim without a referral", async () => {
      const noReferral = "0x0000000000000000000000000000000000000000";
      const amount = 0;
      const proof = [
        "0x11470846972103cbf2c251e83e2499f8fbe25a6424dc17934c81271840db1cef",
        "0xc49b942f9a725fab9c08d4a6252eab55fe71209c11a0a95abe8d11853525c86d",
        "0x9a30aee98573043fb4b9802a4ab110e29be98a0238b09773679485b19504e9dd",
        "0xc3f441f3bbb5fd3a4fe5485361649ed4fcb6f022f81e7dc98bddc3f32e671cd5",
        "0x4923a3cc2b813554de95385210ea6a6e3e2af78a7807a231d1faafa6d11f974e",
        "0x74b1b7afb4fd25cdbf7cdb379c4adf9323651c4202fc6e874a639f585ef46042",
        "0x7f20955ddabef7fcb4299f61d57376fc6cc5c5b85b383f1b783e819ecb6194be",
        "0x805ac5d81bbcb7bc5bcd9a67becb50110d6f42fff19daa2ef3a28a81e6ff3026",
        "0xfe68c295f0a224949a25212893b81c57243f88713750630ec44d2f575b19eb24",
        "0x226bc9ffbb27b2ae8c79a1ed7b9e5b4b68950a89e99dbab6b6e73ca495dcdcb2",
        "0xb9c44b58729edf081e44deecc7ba8cbcf2a223614a73ff33f65fac0eac80dddc",
        "0x27828ab2fbca6afec380839a1e192b5a019bb64503e1929145666356c0d9c4c5",
        "0x950ca4506db91b881ecf335349df03c320952d1ba09e460bbc4f231274a0fbbd",
        "0x385d51367babf27c3fe830d64976e9e9affd29a50ab0d6d2121970a7c02747f1",
        "0xde2d2601929d64613d1c04ef046c041301eae2b39254ea04de5d676d58ae8ed3",
        "0x7c6969261cddab75d971bc975a7fcc0bf38fb09039a8e93038262f8c5ad89467",
      ]; // TODO: add the real proof

      const stakeId = await stake.idCounter();
      await freeClaim.freeClaim(amount, proof, noReferral);
      const owner = await stake.ownerOf(stakeId);
      expect(owner).to.be.eq(deployer.address);
    });

    it("should make a free claim with a referral", async () => {
      const amount = 0;
      const proof = [
        "0x11470846972103cbf2c251e83e2499f8fbe25a6424dc17934c81271840db1cef",
        "0xc49b942f9a725fab9c08d4a6252eab55fe71209c11a0a95abe8d11853525c86d",
        "0x9a30aee98573043fb4b9802a4ab110e29be98a0238b09773679485b19504e9dd",
        "0xc3f441f3bbb5fd3a4fe5485361649ed4fcb6f022f81e7dc98bddc3f32e671cd5",
        "0x4923a3cc2b813554de95385210ea6a6e3e2af78a7807a231d1faafa6d11f974e",
        "0x74b1b7afb4fd25cdbf7cdb379c4adf9323651c4202fc6e874a639f585ef46042",
        "0x7f20955ddabef7fcb4299f61d57376fc6cc5c5b85b383f1b783e819ecb6194be",
        "0x805ac5d81bbcb7bc5bcd9a67becb50110d6f42fff19daa2ef3a28a81e6ff3026",
        "0xfe68c295f0a224949a25212893b81c57243f88713750630ec44d2f575b19eb24",
        "0x226bc9ffbb27b2ae8c79a1ed7b9e5b4b68950a89e99dbab6b6e73ca495dcdcb2",
        "0xb9c44b58729edf081e44deecc7ba8cbcf2a223614a73ff33f65fac0eac80dddc",
        "0x27828ab2fbca6afec380839a1e192b5a019bb64503e1929145666356c0d9c4c5",
        "0x950ca4506db91b881ecf335349df03c320952d1ba09e460bbc4f231274a0fbbd",
        "0x385d51367babf27c3fe830d64976e9e9affd29a50ab0d6d2121970a7c02747f1",
        "0xde2d2601929d64613d1c04ef046c041301eae2b39254ea04de5d676d58ae8ed3",
        "0x7c6969261cddab75d971bc975a7fcc0bf38fb09039a8e93038262f8c5ad89467",
      ]; // TODO: add the real proof

      const stakeId = await stake.idCounter();
      await freeClaim.freeClaim(amount, proof, signers[1].address);
      await freeClaim.stakeClaim();
      const userStake = await stake.stakes(stakeId);
      expect(userStake.owner).to.be.eq(deployer.address);
      const referralStake = await stake.stakes(1);
      expect(referralStake.owner).to.be.eq(signers[1].address);
    });
  });
});
