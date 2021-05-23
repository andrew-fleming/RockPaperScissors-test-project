import { ethers } from "hardhat"
import chai, { expect } from "chai";
import { solidity } from "ethereum-waffle"
import { Contract, BigNumber } from "ethers"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { time } from "@openzeppelin/test-helpers";

chai.use(solidity)

describe("RockPaperScissors Contract", () => {

    let res: any
    let expected: any

    let contract: Contract
    let mockDai: Contract

    let alice: SignerWithAddress
    let bob: SignerWithAddress
    let carol: SignerWithAddress

    const daiAmount: BigNumber = ethers.utils.parseEther("25000");

    before(async() => {
        const MockDai = await ethers.getContractFactory("MockDai");
        const RockPaperScissors = await ethers.getContractFactory("RockPaperScissors");

        [alice, bob, carol] = await ethers.getSigners();

        mockDai = await MockDai.deploy()
        contract = await RockPaperScissors.deploy(mockDai.address)

        /**
         * Mint mockDai for players
         */
        await Promise.all([
            mockDai.mint(alice.address, daiAmount),
            mockDai.mint(bob.address, daiAmount),
            mockDai.mint(carol.address, daiAmount),
        ])
    })

    describe("Init", async() => {
        it("deploys", async() => {
            expect(contract).to.be.ok
            expect(mockDai).to.be.ok
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

        it("should revert withdrawal without requisite funds", async() => {
            await expect(contract.withdraw(daiAmount))
                .to.be.revertedWith("Insufficient funds")
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
            expect(await contract.gameId())
                .to.eq(0)

            let betAmount = ethers.utils.parseEther("5")
            await contract.createGame(betAmount)

            expect(await contract.gameId())
                .to.eq(1)
        })

        it("should create struct with correct data", async() => {
            res = await contract.games(0)

            // check address
            expect(res[0]).to.eq(alice.address)

            // check gameId
            expect(res[5]).to.eq(0)

            // check betAmount
            expect(res[6]).to.eq(ethers.utils.parseEther("5"))
        })

        it("should update state variables", async() => {
            expect(await contract.gameId())
                .to.eq(1)
            
            expect(await contract.openGame(0))
                .to.eq(true)
        })
    })

    describe("discardCreatedGame function", async() => {
        it("should remove openGame status and return funds", async() => {
            await contract.discardCreatedGame(0)

            expect(await contract.openGame(0))
                .to.eq(false)

            expect(await contract.userBalance(alice.address))
                .to.eq(ethers.utils.parseEther("24999"))
        })

        it("should revert when different player calls discardCreatedGame", async() => {
            await contract.createGame(ethers.utils.parseEther("5"))

            await expect(contract.connect(bob).discardCreatedGame(1))
                .to.be.reverted
        })
    })

    describe("joinGame function", async() => {
        it("should join open game and update variables", async() => {
            await mockDai.connect(bob).approve(contract.address, daiAmount) 
            await contract.connect(bob).deposit(daiAmount)
            await contract.connect(bob).joinGame(1)

            expect(await contract.openGame(1))
                .to.eq(false)

            res = await contract.games(1)
            expect(res[1])
                .to.eq(bob.address)

            expect(await contract.userBalance(bob.address))
                .to.eq(ethers.utils.parseEther("24995"))
        })

        it("should revert joining closed game", async() => {
            await mockDai.connect(carol).approve(contract.address, daiAmount)
            await contract.connect(carol).deposit(daiAmount)
            await expect(contract.connect(carol).joinGame(1))
                .to.be.revertedWith("Either game is closed or insufficient funds")
        })
    })

    describe("sendMove function", async() => {
        it("should assign move and timestamp", async() => {
            // Params => gameId, move (1 for ROCK)
            await contract.sendMove(1, 1)

            res = await contract.games(1)
            // p1Move
            expect(res[2]).to.eq(1)

            res = await contract.games(1)
            // startTime
            let formatRes =  Number(res[4].toString())
            expect(formatRes).to.be.greaterThan(0)
        })

        it("should revert sendMove to a discarded game", async() => {
            await expect(contract.sendMove(0, 1))
                .to.be.revertedWith("Either incorrect gameId, move already sent, or game finished")
        })

        it("should revert function call from non-player", async() => {
            await expect(contract.connect(carol).sendMove(1, 3))
                .to.be.revertedWith("Either incorrect gameId, move already sent, or game finished")
        })

        it("should revert from player resending a move", async() => {
            await expect(contract.sendMove(1, 3))
                .to.be.revertedWith("Either incorrect gameId, move already sent, or game finished")
        })

        it("should revert from timeout", async() => {
            await time.increase(300)
            await expect(contract.connect(bob).sendMove(1, 3))
                .to.be.revertedWith("Timed out")
        })
    })
})

describe("Starting from deployment", () => {

    let contract: Contract
    let mockDai: Contract

    let alice: SignerWithAddress
    let bob: SignerWithAddress
    let carol: SignerWithAddress

    const daiAmount: BigNumber = ethers.utils.parseEther("25000");

    beforeEach(async() => {
        const MockDai = await ethers.getContractFactory("MockDai");
        const RockPaperScissors = await ethers.getContractFactory("RockPaperScissors");

        [alice, bob, carol] = await ethers.getSigners();

        mockDai = await MockDai.deploy()
        contract = await RockPaperScissors.deploy(mockDai.address)

        /**
         * Mint, approve, and deposit mockDai for alice, bob, and carol
         */
        await Promise.all([
            mockDai.mint(alice.address, daiAmount),
            mockDai.mint(bob.address, daiAmount),
            mockDai.mint(carol.address, daiAmount),
            mockDai.approve(contract.address, daiAmount),
            mockDai.connect(bob).approve(contract.address, daiAmount),
            mockDai.connect(carol).approve(contract.address, daiAmount),
            contract.deposit(daiAmount),
            contract.connect(bob).deposit(daiAmount),
            contract.connect(carol).deposit(daiAmount)
        ])

        let betAmount = ethers.utils.parseEther("10")
        await contract.createGame(betAmount)
        await contract.connect(bob).joinGame(0)
    })

    describe("calculates correct outcomes for finishGame function", async() => {
        it("checks isP1Winner mapping logic", async() => {
            // True
            expect(await contract.isP1Winner(1, 3)).to.eq(true)
            expect(await contract.isP1Winner(2, 1)).to.eq(true)
            expect(await contract.isP1Winner(3, 2)).to.eq(true)

            // False
            expect(await contract.isP1Winner(3, 1)).to.eq(false)
            expect(await contract.isP1Winner(1, 2)).to.eq(false)
            expect(await contract.isP1Winner(2, 3)).to.eq(false)

            // Draw => False
            expect(await contract.isP1Winner(1, 1)).to.eq(false)
            expect(await contract.isP1Winner(2, 2)).to.eq(false)
            expect(await contract.isP1Winner(3, 3)).to.eq(false)
        })

        it("rock vs rock", async() => {
            await contract.sendMove(0, 1)

            expect(await contract.connect(bob).sendMove(0, 1))
                .to.emit(contract, 'Outcome')
                .withArgs(0, "0x0000000000000000000000000000000000000000");
        })

        it("rock vs paper", async() => {
            await contract.sendMove(0, 1)

            expect(await contract.connect(bob).sendMove(0, 2))
                .to.emit(contract, 'Outcome')
                .withArgs(0, bob.address);
        })

        it("scissors vs rock", async() => {
            await contract.sendMove(0, 3)

            expect(await contract.connect(bob).sendMove(0, 2))
                .to.emit(contract, "Outcome")
                .withArgs(0, alice.address)
        })
    })

    describe("Timeout function", async() => {
        it("should update balances with 20% delayFee", async() => {
            await contract.sendMove(0, 1)
            await time.increase(301)
            await contract.timeOut(0)

            expect(await contract.userBalance(alice.address))
                .to.eq(ethers.utils.parseEther("25002"))

            expect(await contract.userBalance(bob.address))
                .to.eq(ethers.utils.parseEther("24998"))
        })

        it("should revert when non-player calls function", async() => {
            await contract.sendMove(0, 1)
            await time.increase(301)
            await expect(contract.connect(carol).timeOut(0))
                .to.be.revertedWith("Either player not in game or game is finished")
        })

        it("should revert when not enough time elapses", async() => {
           await contract.sendMove(0, 1)
           await time.increase(200)
           await expect(contract.timeOut(0))
                .to.be.revertedWith("Time not exceeded")
        })

        it("should revert when game is finished", async() => {
            await contract.sendMove(0, 1)
            await time.increase(301)
            await contract.timeOut(0)
            await expect(contract.timeOut(0))
                .to.be.revertedWith("Either player not in game or game is finished")
        })
    })
})