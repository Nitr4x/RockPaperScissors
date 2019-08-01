'use strict';

const Factory = artifacts.require('Factory');
const RockPaperScissors = artifacts.require('RockPaperScissors');
const truffleAssert = require('truffle-assertions');

const {toWei, utf8ToHex} = web3.utils;
const BN = require('big-number');

contract('RockPaperScissors', (accounts) => {
    const owner = accounts[0];
    const player1 = accounts[0];
    const player2 = accounts[1];
    const stranger = accounts[2];
    const nilAddress = "0x0000000000000000000000000000000000000000";
    const nonce = utf8ToHex("123456");
    const name = utf8ToHex("RockPaperScissors");

    let factory;
    let instance;

    const evmMethod = (method, params = []) => {
        return new Promise(function (resolve, reject) {
            const sendMethod = (web3.currentProvider.sendAsync) ? web3.currentProvider.sendAsync.bind(web3.currentProvider) : web3.currentProvider.send.bind(web3.currentProvider);
            sendMethod(
                {
                    jsonrpc: '2.0',
                    method,
                    params,
                    id: new Date().getSeconds()
                },
                (error, res) => {
                    if (error) {
                        return reject(error);
                    }
    
                    resolve(res.result);
                }
            );
        });
    };
    
    const increaseTime = async (amount) => {
        await evmMethod("evm_increaseTime", [Number(amount)]);
        await evmMethod("evm_mine");
    };

    beforeEach('Creating new game', async () => {
        factory = await Factory.new({from: owner});
        
        await factory.create(name, player1, player2, 60 * 10, 5, {from: owner});

        instance = await RockPaperScissors.at(await factory.games.call(name));
    });

    describe('======= hashMove unit testing =======', () => {
        it('Should fail if the address is not set', async () => {
            await truffleAssert.reverts(
                instance.hashMove(nilAddress, nonce, 1, {from: owner})
            );
        });

        it('Should fail if the nonce is not set', async () => {
            await truffleAssert.reverts(
                instance.hashMove(player1, utf8ToHex(""), 1, {from: player1})
            );
        });    
    });
});