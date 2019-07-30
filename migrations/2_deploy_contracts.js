const Remittance = artifacts.require("./");

module.exports = async function (deployer) {
    await deployer.deploy(Remittance);
};
