task("deploy-timelock")
    .addParam("name", "Name of the staking pool")
    .addParam("symbol", "Symbol of the staking pool")
    .addParam("depositToken", "Token which users deposit")
    .addParam("rewardToken", "Token users will receive as reward")
    .addParam("escrowPool", "Pool used to escrow rewards")
    .addParam("escrowPortion", "Portion being escrowed, 1 == 100%")
    .addParam("escrowDuration", "How long tokens will be escrowed")
    .addParam("maxBonus", "Maximum bonus for locking longer, 1 == 100% bonus")
    .addParam("maxLockDuration", "After how long the bonus is maxed out, in seconds")
    .setAction(async (taskArgs, { ethers, run }) => {
        const [deployer] = await ethers.getSigners();

        console.log("Deploying TimeLockNonTransferablePool");

        // deploy timelock
        TimelockFactory = await ethers.getContractFactory('TimeLockNonTransferablePool', deployer)
        timelockContract = await TimelockFactory.deploy(
            taskArgs.name,
            taskArgs.symbol,
            taskArgs.depositToken,
            taskArgs.rewardToken,
            taskArgs.escrowPool,
            ethers.utils.parseEther(taskArgs.escrowPortion),
            taskArgs.escrowDuration,
            ethers.utils.parseEther(taskArgs.maxBonus),
            taskArgs.maxLockDuration
        )
        await timelockContract.deployed()
        console.log(`TimeLockNonTransferablePool deployed at: ${timelockContract.address}`);
        return timelockContract;
    });