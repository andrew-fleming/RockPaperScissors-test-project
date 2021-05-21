import { ethers } from "hardhat"
import chai, { expect } from "chai";
import { solidity } from "ethereum-waffle"
import { Contract, BigNumber, providers } from "ethers"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

chai.use(solidity)

describe("RockPaperScissors Contract", () => {

    let res: any
    let expected: any

    let contract: Contract
    let mockDai: Contract

    let alice: SignerWithAddress
    let bob: SignerWithAddress
    let carol: SignerWithAddress
    let dave: SignerWithAddress
    let eve: SignerWithAddress

    const daiAmount: BigNumber = ethers.utils.parseEther("25000");

    before(async() => {
        const MockDai = await ethers.getContractFactory("MockDai");
        const RockPaperScissors = await ethers.getContractFactory("RockPaperScissors");

        [alice, bob, carol, dave, eve] = await ethers.getSigners();

        mockDai = await MockDai.deploy()
        contract = await RockPaperScissors.deploy(mockDai.address)

        /**
         * Mint mockDai for players
         */
        await Promise.all([
            mockDai.mint(alice.address, daiAmount),
            mockDai.mint(bob.address, daiAmount),
            mockDai.mint(carol.address, daiAmount),
            mockDai.mint(dave.address, daiAmount),
            mockDai.mint(eve.address, daiAmount)
        ])
    })

    describe("Init", async() => {
        it("deploys", async() => {
            expect(contract)
                .to.be.ok
            
            expect(mockDai)
                .to.be.ok
        })

        it("minted mockDai correctly", async() => {
            res = await mockDai.balanceOf(alice.address)
            expect(res.toString())
                .to.eq(daiAmount)
        })
    })

    describe("Deposit function", async() => {
        it("should deposit all mDai to the contract", async() => {
            await mockDai.approve(contract.address, daiAmount)
            await contract.deposit(daiAmount)
        })

        it("should update user and contract balances", async() => {
            expect(await contract.userBalance(alice.address))
                .to.eq(daiAmount)

            expect(await mockDai.balanceOf(contract.address))
                .to.eq(daiAmount)

            expect(await mockDai.balanceOf(alice.address))
                .to.eq("0")
        })

        it("should revert with insufficient funds", async() => {
            await expect(contract.deposit(1))
                .to.be.revertedWith("Insufficient funds")
        })
    })

    describe("Withdraw function", async() => {
        it("should withdraw correct amount", async() => {
            let amt = ethers.utils.parseEther("1")
            await contract.withdraw(amt)

            expect(await mockDai.balanceOf(alice.address))
                .to.eq(amt)
        })

        it("should revert", async() => {
            await expect(contract.withdraw(daiAmount))
                .to.be.reverted
        })

        it("should update balance", async() => {
            expect(await contract.userBalance(alice.address))
                .to.eq(ethers.utils.parseEther("24999"))
        })
    })

    describe("createGame function", async() => {
        it("should revert with zero userBalance in contract", async() => {
            await expect(contract.connect(bob).createGame(100))
                .to.be.revertedWith("Insufficient funds")
        })

        it("should create a game and update gameId", async() => {
            res = await contract.gameId()

            let betAmount = ethers.utils.parseEther("5")

            expect(await contract.createGame(betAmount))
                .to.be.ok

            let newResult = await contract.gameId()

            expect(Number(newResult))
                .to.be.greaterThan(Number(res))
        })

        it("should create struct with correct data", async() => {
            res = await contract.games(0)

            // check address
            expect(res[0])
                .to.eq(alice.address)

            // check gameId
            expect(res[5])
                .to.eq(0)

            // check betAmount
            expect(res[6])
                .to.eq(ethers.utils.parseEther("5"))
        })

    })

})