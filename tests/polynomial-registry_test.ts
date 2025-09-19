import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.6/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Verify Computational Node Registration",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const nodeOwner = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall('polynomial-registry', 'register-computational-node', [
                types.ascii('High-Performance Node'),
                types.ascii('Advanced computational node for complex calculations'),
                types.ascii('Machine Learning'),
                types.ascii('GPU Acceleration, Deep Learning'),
                types.ascii('Tensor Computations'),
                types.uint(100),
                types.uint(50)
            ], nodeOwner.address)
        ]);

        // Assert registration was successful
        assertEquals(block.height, 2);
        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk().expectUint(0);  // First registered node has ID 0
    }
});

Clarinet.test({
    name: "Prevent Excessive Node Registration",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const nodeOwner = accounts.get('wallet_1')!;

        // Attempt to register more than 50 nodes
        const registrationTxs = Array(51).fill(null).map(() => 
            Tx.contractCall('polynomial-registry', 'register-computational-node', [
                types.ascii('Test Node'),
                types.ascii('Computational Test Node'),
                types.ascii('Testing'),
                types.ascii('Computation'),
                types.ascii('Test Data'),
                types.uint(10),
                types.uint(5)
            ], nodeOwner.address)
        );

        let block = chain.mineBlock(registrationTxs);

        // Assert last registration fails due to node limit
        block.receipts[50].result.expectErr().expectUint(106);  // ERR-USER-NODE-LIMIT-REACHED
    }
});