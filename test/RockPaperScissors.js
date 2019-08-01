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
    const nil = "0x0000000000000000000000000000000000000000";
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

    describe('======= contract constructor unit testing =======', () => {
        beforeEach('Creating factory', async () => {
            factory = await Factory.new({from: owner});
        });

        it('Should fail if players\' addresses are nul', async () => {
            await truffleAssert.reverts(
                factory.create(name, player1, nil, 60 * 6, 5, {from: owner})
            );

            await truffleAssert.reverts(
                factory.create(name, nil, player2, 60 * 6, 5, {from: owner})
            );
        });

        it('Should fail if the deadline is below 5 minutes', async () => {
            await truffleAssert.reverts(
                factory.create(name, player1, player2, 60 * 4, 5)
            );
        });
    });

    describe('======= contract method unit testing =======', () => {
        beforeEach('Creating new game', async () => {
            factory = await Factory.new({from: owner});
            
            await factory.create(name, player1, player2, 60 * 10, 5, {from: owner});
    
            instance = await RockPaperScissors.at(await factory.games.call(name));
        });
    
        describe('======= hashMove unit testing =======', () => {
            it('Should fail if the address is not set', async () => {
                await truffleAssert.reverts(
                    instance.hashMove(nil, nonce, 1, {from: owner})
                );
            });
    
            it('Should fail if the nonce is not set', async () => {
                await truffleAssert.reverts(
                    instance.hashMove(player1, utf8ToHex(""), 1, {from: player1})
                );
            });    
        });

        describe('======= placeMove unit testing =======', () => {
            let hashedMove;

            beforeEach('Creating hashedMove', async () => {
                hashedMove = await instance.hashMove(player1, nonce, 1, {from: player1});
            });

            it('Should be able to place a move', async () => {
                let initialBalance = new BN(await web3.eth.getBalance(player1));

                const txObj = await instance.placeMove(hashedMove, {
                    from: player1,
                    value: 5
                });
                const gasPrice = (await web3.eth.getTransaction(txObj.tx)).gasPrice;

                assert.strictEqual(txObj.logs.length, 1);
                assert.strictEqual(txObj.logs[0].event, "LogMovePlaced");
                assert.strictEqual(txObj.logs[0].args[0], player1);
                assert.strictEqual(txObj.logs[0].args[1], hashedMove);
                
                initialBalance.minus(txObj.receipt.gasUsed * gasPrice);
                initialBalance.minus(5);
                assert.strictEqual(initialBalance.toString(), await web3.eth.getBalance(player1));

                const state = await instance._players.call(player1);
                assert.strictEqual(hashedMove, state.hashedMove);
                assert.strictEqual("5", state.bet.toString());
            });

            it('Should not be able to place a move once the deadline reached', async () => {
                await increaseTime(11 * 60);

                await truffleAssert.reverts(
                    instance.placeMove(hashedMove, {
                        from: player1,
                        value: 5
                    })
                );
            });

            it('Should fail if the player does not exist', async () => {
                await truffleAssert.reverts(
                    instance.placeMove(hashedMove, {
                        from: stranger,
                        value: 5
                    })
                );
            });

            it('Should fail if the bet is wrong', async () => {
                await truffleAssert.reverts(
                    instance.placeMove(hashedMove, {
                        from: player1,
                        value: 1
                    })
                );
            });

            it('Should fail if the hashedMove is nul', async () => {
                truffleAssert.reverts(
                    instance.placeMove(utf8ToHex(""), {
                        from: player1,
                        value: 5
                    })
                );
            });

            it('Should fail if the player has already played', async () => {
                await instance.placeMove(hashedMove, {
                    from: player1,
                    value: 5
                });

                truffleAssert.reverts(
                    instance.placeMove(hashedMove, {
                        from: player1,
                        value: 5
                    })
                );
            });
        });

        describe('======= resolve & revealMove unit testing =======', () => {
            let hashedMoveP1;
            let hashedMoveP2;

            beforeEach('Generating hashed moves', async () => {
                hashedMoveP1 = await instance.hashMove(player1, nonce, 1, {from: player1});
                hashedMoveP2 = await instance.hashMove(player2, nonce, 2, {from: player2});
            });

            describe('======= revealMove unit testing =======', () => {
                beforeEach('Placing moves', async () => {
                    await instance.placeMove(hashedMoveP1, {
                        from: player1,
                        value: 5
                    });
    
                    await instance.placeMove(hashedMoveP2, {
                        from: player2,
                        value: 5
                    });
                });

                it('Should fail if the nonce is invalid', async () => {
                    await truffleAssert.reverts(
                        instance.resolve(player1, utf8ToHex(""), 1, player2, nonce, 2, {from: player1})
                    );
                });

                it('Should fail if the move is invalid', async () => {
                    await truffleAssert.reverts(
                        instance.resolve(player1, nonce, 2, player2, nonce, 2, {from: player1})
                    );
                });
            });

            describe('======= resolve unit testing =======', () => {
                it('Should fail if a player has not played yet', async () => {
                    await instance.placeMove(hashedMoveP1, {
                        from: player1,
                        value: 5
                    });
                    
                    await truffleAssert.reverts(
                        instance.resolve(player1, nonce, 1, player2, nonce, 2, {from: player1})
                    );
                });

                it('Player2 should win', async () => {
                    await instance.placeMove(hashedMoveP1, {
                        from: player1,
                        value: 5
                    });
    
                    await instance.placeMove(hashedMoveP2, {
                        from: player2,
                        value: 5
                    });

                    const txObj = await instance.resolve(player1, nonce, 1, player2, nonce, 2, {from: player1});
                    assert.strictEqual(txObj.logs.length, 3);
                    assert.strictEqual(txObj.logs[0].event, "LogMoveRevealed");
                    assert.strictEqual(txObj.logs[0].args[0], player1);
                    assert.strictEqual(txObj.logs[1].event, "LogMoveRevealed");
                    assert.strictEqual(txObj.logs[1].args[0], player2);
                    assert.strictEqual(txObj.logs[2].event, "LogGameResolved");
                    assert.strictEqual(txObj.logs[2].args[0], player2);
                    assert.strictEqual(txObj.logs[2].args[1], player1);

                    const player1State = await instance._players.call(player1);
                    const player2State = await instance._players.call(player2);

                    assert.strictEqual(player1State.bet.toString(), "0");
                    assert.strictEqual(player2State.bet.toString(), "10");
                });
            });
        });

        describe('======= withdraw unit testing =======', () => {
            let hashedMoveP1;
            let hashedMoveP2;

            beforeEach('Generating hashed move', async () => {
                hashedMoveP1 = await instance.hashMove(player1, nonce, 1, {from: player1});
                hashedMoveP2 = await instance.hashMove(player2, nonce, 2, {from: player2});
            });

            it('Should not be able to withdraw is the player does not exist', async () => {
                truffleAssert.reverts(
                    instance.withdraw({from: stranger})
                );
            });

            it('Should fail to withdraw if the player is not the winner', async () => {
                await instance.placeMove(hashedMoveP1, {
                    from: player1,
                    value: 5
                });

                await instance.placeMove(hashedMoveP2, {
                    from: player2,
                    value: 5
                });

                await instance.resolve(player1, nonce, 1, player2, nonce, 2, {from: player1});

                await truffleAssert.reverts(
                    instance.withdraw({from: player1})
                );
            });

            it('Should be able to withdraw once the deadline reach', async () => {
                await instance.placeMove(hashedMoveP1, {
                    from: player1,
                    value: 5
                });
                
                await increaseTime(11 * 60);

                let initialBalanceP1 = new BN(await web3.eth.getBalance(player1));

                const txObj = await instance.withdraw({from: player1});
                const gasPrice = (await web3.eth.getTransaction(txObj.tx)).gasPrice;

                assert.strictEqual(txObj.logs.length, 1);
                assert.strictEqual(txObj.logs[0].event, "LogBalanceWithdrawed");
                assert.strictEqual(txObj.logs[0].args[0], player1);
                assert.strictEqual(txObj.logs[0].args[1].toString(), "5");

                initialBalanceP1.minus(txObj.receipt.gasUsed * gasPrice);
                initialBalanceP1.add(5);
                assert.strictEqual(initialBalanceP1.toString(), await web3.eth.getBalance(player1));
            });

            it('Should deplete winner bet', async () => {
                await instance.placeMove(hashedMoveP1, {
                    from: player1,
                    value: 5
                });

                await instance.placeMove(hashedMoveP2, {
                    from: player2,
                    value: 5
                });

                await instance.resolve(player1, nonce, 1, player2, nonce, 2, {from: player1});

                let initialBalance = new BN(await web3.eth.getBalance(player2));

                const txObj = await instance.withdraw({from: player2});
                const gasPrice = (await web3.eth.getTransaction(txObj.tx)).gasPrice;

                assert.strictEqual(txObj.logs.length, 1);
                assert.strictEqual(txObj.logs[0].event, "LogBalanceWithdrawed");
                assert.strictEqual(txObj.logs[0].args[0], player2);
                assert.strictEqual(txObj.logs[0].args[1].toString(), "10");

                initialBalance.minus(txObj.receipt.gasUsed * gasPrice);
                initialBalance.add(10);
                assert.strictEqual(initialBalance.toString(), await web3.eth.getBalance(player2));
            });
        });
    })
});