'use strict';

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
        instance = await RockPaperScissors.new();
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

        it('Should fail if the move is NONE', async () => {
            truffleAssert.reverts(
                instance.hashMove(player1, nonce, 0, {from: player1})
            );
        });
    });

    describe('======= create unit testing =======', async () => {
        let hashedMove;

        beforeEach('Create hashedMove', async () => {
            hashedMove = await instance.hashMove(player1, nonce, 1, {from: player1});
        });

        it('Should create a new game', async () => {
            let initialBalance = new BN(await web3.eth.getBalance(player1));

            const txObj = await instance.create(hashedMove, player2, 60 * 6, 5, {
                from: player1,
                value: 5
            });
            const gasPrice = (await web3.eth.getTransaction(txObj.tx)).gasPrice;

            assert.strictEqual(txObj.logs.length, 1);
            assert.strictEqual(txObj.logs[0].event, "LogGameCreated");
            assert.strictEqual(txObj.logs[0].args[0], hashedMove);
            assert.strictEqual(txObj.logs[0].args[1], player1);
            assert.strictEqual(txObj.logs[0].args[2], player2);
            
            initialBalance.minus(txObj.receipt.gasUsed * gasPrice);
            initialBalance.minus(5);
            assert.strictEqual(initialBalance.toString(), await web3.eth.getBalance(player1));
        });

        it('Should fail if hashedMove is nul', async () => {
            await truffleAssert.reverts(
                instance.create(utf8ToHex(""), player2, 60 * 6, 5, {
                    from: owner,
                    value: 5
                })
            );
        });

        it('Should fail if opponent address is nul', async () => {
            await truffleAssert.reverts(
                instance.create(utf8ToHex(""), player2, 60 * 6, 5, {
                    from: owner,
                    value: 5
                })
            );
        });

        it('Should fail if the deadline is below 5 minutes', async () => {
            await truffleAssert.reverts(
                instance.create(hashedMove, player2, 60 * 4, 5, {
                    from: owner,
                    value: 5
                })
            );
        });

        it('Should fail if the amount of ether sent does not match with the bet', async () => {
            await truffleAssert.reverts(
                instance.create(hashedMove, player2, 60 * 6, 5, {
                    from: owner,
                    value: 4
                })
            );
        });

        it('Should fail if hashedMove already exist', async () => {
            await instance.create(hashedMove, player2, 60 * 6, 5, {
                from: owner,
                value: 5
            });

            await truffleAssert.reverts(
                instance.create(hashedMove, player2, 60 * 6, 5, {
                    from: owner,
                    value: 5
                })
            );
        });
    });

    describe('======= placeMove unit testing =======', () => {
        let hashedMove;

        beforeEach('Creating hashedMove', async () => {
            hashedMove = await instance.hashMove(player1, nonce, 1, {from: player1});

            await instance.create(hashedMove, player2, 60 * 6, 5, {
                from: owner,
                value: 5
            });
        });

        it('Should be able to place a move', async () => {
            let initialBalance = new BN(await web3.eth.getBalance(player2));

            const txObj = await instance.placeMove(hashedMove, 2, {
                from: player2,
                value: 5
            });
            const gasPrice = (await web3.eth.getTransaction(txObj.tx)).gasPrice;

            assert.strictEqual(txObj.logs.length, 1);
            assert.strictEqual(txObj.logs[0].event, "LogMovePlaced");
            assert.strictEqual(txObj.logs[0].args[0], hashedMove);
            assert.strictEqual(txObj.logs[0].args[1], player2);
            assert.strictEqual(txObj.logs[0].args[2].toString(), "2");
            
            initialBalance.minus(txObj.receipt.gasUsed * gasPrice);
            initialBalance.minus(5);
            assert.strictEqual(initialBalance.toString(), await web3.eth.getBalance(player2));

            const game = await instance.games.call(hashedMove);
            assert.strictEqual("2", game.opponentMove.toString());
        });

        it('Should not be able to place a move once the deadline reached', async () => {
            await increaseTime(11 * 60);

            await truffleAssert.reverts(
                instance.placeMove(hashedMove, 2, {
                    from: player2,
                    value: 5
                })
            );
        });

        it('Should fail if the player is not the opponent', async () => {
            await truffleAssert.reverts(
                instance.placeMove(hashedMove, 2, {
                    from: stranger,
                    value: 5
                })
            );
        });

        it('Should fail if the bet is wrong', async () => {
            await truffleAssert.reverts(
                instance.placeMove(hashedMove, 2, {
                    from: player2,
                    value: 1
                })
            );
        });

        it('Should fail if the hashedMove is nul', async () => {
            await truffleAssert.reverts(
                instance.placeMove(utf8ToHex(""), 2, {
                    from: player2,
                    value: 5
                })
            );
        });

        it('Should fail if the player has already played', async () => {
            await instance.placeMove(hashedMove, 2, {
                from: player2,
                value: 5
            });

            await truffleAssert.reverts(
                instance.placeMove(hashedMove, 2, {
                    from: player2,
                    value: 5
                })
            );
        });
    });

    describe('======= resolve unit testing =======', () => {
        let hashedMove;

        beforeEach('Generating hashed moves', async () => {
            hashedMove = await instance.hashMove(player1, nonce, 1, {from: player1});

            await instance.create(hashedMove, player2, 60 * 6, 5, {
                from: player1,
                value: 5
            });
        });

        it('Should fail if the opponent has not played yet', async () => {
            await truffleAssert.reverts(
                instance.resolve(hashedMove, nonce, 1, {
                    from: player1
                })
            );
        });

        it('Should fail if the game is ended', async () => {
            await instance.placeMove(hashedMove, 2, {
                from: player2,
                value: 5
            });

            await increaseTime(60 * 60);
            
            await truffleAssert.reverts(
                instance.resolve(hashedMove, nonce, 1, {
                    from: player1
                })
            );
        });

        it('Should fail if the game session is wrong', async () => {
            await instance.placeMove(hashedMove, 2, {
                from: player2,
                value: 5
            });

            await truffleAssert.reverts(
                instance.resolve(utf8ToHex("wronghash"), nonce, 1, {
                    from: player1
                })
            );
        });

        it('Should resolve the game', async () => {
            await instance.placeMove(hashedMove, 2, {
                from: player2,
                value: 5
            });
            
            const txObj = await instance.resolve(hashedMove, nonce, 1, {
                from: player1
            });

            assert.strictEqual(txObj.logs.length, 1);
            assert.strictEqual(txObj.logs[0].event, "LogGameResolved");
            assert.strictEqual(txObj.logs[0].args[0], hashedMove);
            assert.strictEqual(txObj.logs[0].args[1], player2);
            assert.strictEqual(txObj.logs[0].args[2], player1);
        });
    });

    describe('======= cancel unit testing =======', () => {
        let hashedMove;

        beforeEach('Generating hashed moves', async () => {
            hashedMove = await instance.hashMove(player1, nonce, 1, {from: player1});

            await instance.create(hashedMove, player2, 60 * 6, 5, {
                from: player1,
                value: 5
            });
        });

        it('Should be able to cancel the game', async () => {
            const txObj = await instance.cancel(hashedMove, nonce, 1, {from: player1});

            assert.strictEqual(txObj.logs.length, 1);
            assert.strictEqual(txObj.logs[0].event, "LogGameCancelled");
            assert.strictEqual(txObj.logs[0].args[0], hashedMove);
            assert.strictEqual(txObj.logs[0].args[1], player1);
        });

        it('Should not be able to cancel the game if the opponent has played', async () => {
            await instance.placeMove(hashedMove, 2, {
                from: player2,
                value: 5
            });
            
            await truffleAssert.reverts(
                instance.cancel(hashedMove, nonce, 1, {from: player1})
            );
        });

        it('Should not be able to cancel the game by the opponent', async () => {      
            await truffleAssert.reverts(
                instance.cancel(hashedMove, nonce, 1, {from: player2})
            );
        });

        it('Should not be able to cancel if the nonce is wrong', async () => {
            await truffleAssert.reverts(
                instance.cancel(hashedMove, utf8ToHex(""), 1, {from: player1})
            );
        });

        it('Should not be able to cancel the game if the move is wrong', async () => {
            await truffleAssert.reverts(
                instance.cancel(hashedMove, nonce, 2, {from: player1})
            );
        });

        it('Should not be able to cancel the game if resolved', async () => {
            await instance.placeMove(hashedMove, 2, {
                from: player2,
                value: 5
            });
            
            await instance.resolve(hashedMove, nonce, 1, {
                from: player1
            });

            await truffleAssert.reverts(
                instance.cancel(hashedMove, nonce, 1, {from: player1})
            );
        });
    });

    describe('======= penalize unit testing =======', () => {
        let hashedMove;

        beforeEach('Generating hashed moves', async () => {
            hashedMove = await instance.hashMove(player1, nonce, 1, {from: player1});

            await instance.create(hashedMove, player2, 60 * 6, 5, {
                from: player1,
                value: 5
            });
        });

        it('Should be able to penalize the game owner', async () => {
            await instance.placeMove(hashedMove, 2, {
                from: player2,
                value: 5
            }); 

            await increaseTime(7 * 60);

            const txObj = await instance.penalize(hashedMove, {from: player2});

            assert.strictEqual(txObj.logs.length, 1);
            assert.strictEqual(txObj.logs[0].event, "LogPlayerPenalized");
            assert.strictEqual(txObj.logs[0].args[0], hashedMove);
            assert.strictEqual(txObj.logs[0].args[1], player2);
        });

        it('Should not be able to penalize if the game is resolved', async () => {
            await instance.placeMove(hashedMove, 2, {
                from: player2,
                value: 5
            });
          
            await instance.resolve(hashedMove, nonce, 1, {
                from: player1
            });

            await truffleAssert.reverts(
                instance.penalize(hashedMove, {from: player2})
            );
        });

        it('Should not be able to penalize if the timelimit has not been reached yet', async () => {
            await instance.placeMove(hashedMove, 2, {
                from: player2,
                value: 5
            });
            
            await truffleAssert.reverts(
                instance.penalize(hashedMove, {from: player2})
            );
        });

        it('Should not be able to penalize by the game owner', async () => {
            await instance.placeMove(hashedMove, 2, {
                from: player2,
                value: 5
            }); 

            await increaseTime(6 * 60);
            
            await truffleAssert.reverts(
                instance.penalize(hashedMove, {from: player1})
            );
        });

        it('Should not be able to penalize if the opponent has not played', async () => {
            await increaseTime(6 * 30);

            await truffleAssert.reverts(
                instance.penalize(hashedMove, {from: player2})
            );
        });
    });

    describe('======= withdraw unit testing =======', () => {
        let hashedMove;

        beforeEach('Generating hashed moves', async () => {
            hashedMove = await instance.hashMove(player1, nonce, 1, {from: player1});

            await instance.create(hashedMove, player2, 60 * 6, 5, {
                from: player1,
                value: 5
            });
        });

        it('Should withdraw 5 wei when cancel', async () => {
            await instance.cancel(hashedMove, nonce, 1, {from: player1});

            let initialBalance = new BN(await web3.eth.getBalance(player1));

            const txObj = await instance.withdraw({from: player1});
            const gasPrice = (await web3.eth.getTransaction(txObj.tx)).gasPrice;

            assert.strictEqual(txObj.logs.length, 1);
            assert.strictEqual(txObj.logs[0].event, "LogBetWithdrawed");
            assert.strictEqual(txObj.logs[0].args[0], player1);
            assert.strictEqual(txObj.logs[0].args[1].toString(), "5");

            initialBalance.minus(txObj.receipt.gasUsed * gasPrice);
            initialBalance.add(5);
            assert.strictEqual(initialBalance.toString(), await web3.eth.getBalance(player1));
        });

        it('Should withdraw 10 wei when penalized', async () => {
            await instance.placeMove(hashedMove, 2, {
                from: player2,
                value: 5
            });
          
            await increaseTime(60 * 60);

            await instance.penalize(hashedMove, {from: player2})
            let initialBalance = new BN(await web3.eth.getBalance(player2));

            const txObj = await instance.withdraw({from: player2});
            const gasPrice = (await web3.eth.getTransaction(txObj.tx)).gasPrice;

            assert.strictEqual(txObj.logs.length, 1);
            assert.strictEqual(txObj.logs[0].event, "LogBetWithdrawed");
            assert.strictEqual(txObj.logs[0].args[0], player2);
            assert.strictEqual(txObj.logs[0].args[1].toString(), "10");

            initialBalance.minus(txObj.receipt.gasUsed * gasPrice);
            initialBalance.add(10);
            assert.strictEqual(initialBalance.toString(), await web3.eth.getBalance(player2));
        });

        it('Should withdraw 10 wei when the player2 win', async () => {
            await instance.placeMove(hashedMove, 2, {
                from: player2,
                value: 5
            });
          
            await instance.resolve(hashedMove, nonce, 1, {
                from: player1
            });

            let initialBalance = new BN(await web3.eth.getBalance(player2));

            const txObj = await instance.withdraw({from: player2});
            const gasPrice = (await web3.eth.getTransaction(txObj.tx)).gasPrice;

            assert.strictEqual(txObj.logs.length, 1);
            assert.strictEqual(txObj.logs[0].event, "LogBetWithdrawed");
            assert.strictEqual(txObj.logs[0].args[0], player2);
            assert.strictEqual(txObj.logs[0].args[1].toString(), "10");

            initialBalance.minus(txObj.receipt.gasUsed * gasPrice);
            initialBalance.add(10);
            assert.strictEqual(initialBalance.toString(), await web3.eth.getBalance(player2));

            await truffleAssert.reverts(
                instance.withdraw({from: player1})
            );
        });
    });
});
