import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.6/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Verify Computational Access Request Flow",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const nodeOwner = accounts.get('wallet_1')!;
        const requester = accounts.get('wallet_2')!;

        // First, register a node
        let block = chain.mineBlock([
            Tx.contractCall('polynomial-registry', 'register-computational-node', [
                types.ascii('ML Compute Node'),
                types.ascii('Advanced machine learning computational node'),
                types.ascii('Machine Learning'),
                types.ascii('GPU Acceleration'),
                types.ascii('Tensor Computations'),
                types.uint(100),
                types.uint(50)
            ], nodeOwner.address)
        ]);

        const nodeId = block.receipts[0].result.expectOk().expectUint(0);

        // Request computational access
        block = chain.mineBlock([
            Tx.contractCall('polynomial-access', 'request-computational-access', [
                types.uint(nodeId),
                types.ascii('Model Training'),
                types.uint(100),
                types.uint(25),
                types.uint(1),  // One-time payment
                types.uint(0)
            ], requester.address)
        ]);

        // Verify access request was created successfully
        block.receipts[0].result.expectOk().expectUint(0);

        // Approve access request
        block = chain.mineBlock([
            Tx.contractCall('polynomial-access', 'approve-computational-access', [
                types.uint(0)
            ], nodeOwner.address)
        ]);

        block.receipts[0].result.expectOk().expectBool(true);
    }
});

Clarinet.test({
    name: "Prevent Unauthorized Access Request Approval",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const nodeOwner = accounts.get('wallet_1')!;
        const requester = accounts.get('wallet_2')!;
        const unauthorized = accounts.get('wallet_3')!;

        // Register a node
        let block = chain.mineBlock([
            Tx.contractCall('polynomial-registry', 'register-computational-node', [
                types.ascii('GPU Compute Node'),
                types.ascii('High-performance GPU node'),
                types.ascii('Computational Graphics'),
                types.ascii('CUDA Processing'),
                types.ascii('Rendering Computations'),
                types.uint(200),
                types.uint(75)
            ], nodeOwner.address)
        ]);

        const nodeId = block.receipts[0].result.expectOk().expectUint(0);

        // Request computational access
        block = chain.mineBlock([
            Tx.contractCall('polynomial-access', 'request-computational-access', [
                types.uint(nodeId),
                types.ascii('Graphics Rendering'),
                types.uint(50),
                types.uint(40),
                types.uint(1),
                types.uint(0)
            ], requester.address)
        ]);

        const requestId = block.receipts[0].result.expectOk().expectUint(0);

        // Attempt unauthorized approval
        block = chain.mineBlock([
            Tx.contractCall('polynomial-access', 'approve-computational-access', [
                types.uint(requestId)
            ], unauthorized.address)
        ]);

        block.receipts[0].result.expectErr().expectUint(100);  // ERR-NOT-AUTHORIZED
    }
});