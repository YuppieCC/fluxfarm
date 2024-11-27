DEPLOY_CONTRACT ?=
DEPLOYED_CONTRACT_ADDRESS ?=
CONSTRUCTOR_ARGS ?=
VERITY_CONSTRUCTOR_ARGS ?=
VERIFY_CONTRACT ?=
TEST_CONTRACT ?=
GUID ?=
include .env.op

testall:
	forge test --fork-url ${NETWORK_RPC_URL} -vvv

st:
	forge test --match-contract ${TEST_CONTRACT} --fork-url ${NETWORK_RPC_URL} -vvv --via-ir

report:
	forge test --fork-url ${NETWORK_RPC_URL} --gas-report

build:
	forge build

snapshot:
	forge snapshot --fork-url ${NETWORK_RPC_URL}

flatten:
	forge flatten src/${DEPLOY_CONTRACT}.sol --output flattens/${DEPLOY_CONTRACT}Flatten.sol

# deploy the contract
deploy-contract:
	forge create --rpc-url ${NETWORK_RPC_URL} \
		--private-key ${PRIVATE_KEY} \
		--constructor-args $(CONSTRUCTOR_ARGS) \
		src/$(DEPLOY_CONTRACT).sol:$(DEPLOY_CONTRACT) \
		--gas-price ${GAS_PRICE}

# verify the contract
verify-contract:
	forge verify-contract \
		--chain-id ${CHAIN_ID} \
		--num-of-optimizations 1000000 \
		--watch \
		--etherscan-api-key ${ETHERSCAN_KEY} \
		--compiler-version ${COMPILER_VERSION} \
		$(DEPLOYED_CONTRACT_ADDRESS) \
		src/$(VERIFY_CONTRACT).sol:$(VERIFY_CONTRACT)

verify-check:
	forge verify-check --chain-id ${CHAIN_ID} $(GUID) ${ETHERSCAN_KEY}

# deploy contracts and verify them
# make scripting ETH_GAS_PRICE=${GAS_PRICE}
scripting:
	forge script script/${DEPLOY_CONTRACT}.s.sol:${DEPLOY_CONTRACT}Script --rpc-url ${NETWORK_RPC_URL} \
		--optimizer-runs 200 \
		--broadcast \
		--verify \
		--etherscan-api-key ${ETHERSCAN_KEY} \
		--private-key ${PRIVATE_KEY} \
		--gas-price 500000 \
		-vvvv
