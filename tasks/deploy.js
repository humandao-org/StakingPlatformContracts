const HDAO = "0xdac657ffd44a3b9d8aba8749830bf14beb66ff2d";
const ONE_YEAR = 60 * 60 * 24 * 365;

task("deploy")
    .setAction(async (taskArgs, { ethers, run }) => {
        const [deployer] = await ethers.getSigners();

        const escrowPool = await run("deploy-timelock", {
            name: "Staked HDAO",
            symbol: "sHDAO",
            depositToken: HDAO,
            rewardToken: HDAO, //leaves possibility for xSushi like payouts on staked MC
            escrowPool: ethers.constants.AddressZero,
            escrowPortion: "0", //rewards from pool itself are not locked
            escrowDuration: "0", // no rewards escrowed so 0 escrow duration
            maxBonus: "0", // no bonus needed for longer locking durations
            maxLockDuration: (ONE_YEAR * 10).toString(), // Can be used to lock up to 10 years
        });

        console.log("Done deploying!");
    });