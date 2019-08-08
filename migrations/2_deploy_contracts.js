const Factory = artifacts.require("./Factory");

module.exports = async function (deployer) {
    await deployer.deploy(Factory);
};
