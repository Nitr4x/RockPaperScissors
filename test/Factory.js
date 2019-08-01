'use strict';

const Factory = artifacts.require('Factory');
const truffleAssert = require('truffle-assertions');

const {utf8ToHex} = web3.utils;

contract('Factory', (accounts) => {
    const owner = accounts[0];
    const player1 = accounts[0];
    const player2 = accounts[1];
    const name = utf8ToHex("RockPaperScissors");

    let instance;

    beforeEach('Creating new factory', async () => {
        instance = await Factory.new({from: owner});
    });

    describe('======= create unit testing =======', () => {
        it('Should fail if the name is not set', async () => {
            await truffleAssert.reverts(
                instance.create(utf8ToHex(""), player1, player2, 60 * 6, 5, {from: owner})
            );
        });

        it('Should create a new game', async () => {
            const txObj = await instance.create(name, player1, player2, 60 * 6, 5, {from: owner});

            assert.strictEqual(txObj.logs.length, 2);
            assert.strictEqual(txObj.logs[0].event, "PauserAdded");
            assert.strictEqual(txObj.logs[1].event, "LogGameCreated");
            assert.strictEqual(txObj.logs[1].args[0], owner);
            assert.strictEqual(txObj.logs[1].args[1], name.padEnd(66, "0"));
            assert.strictEqual(txObj.logs[1].args[2], await instance.games.call(name));
        });
    });
});