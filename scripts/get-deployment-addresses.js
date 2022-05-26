export async function getDeploymentAddresses(env = "dev") {
  let addresses;

  try {
    addresses = await import(`../deployments/deployment-addresses.${env}.json`)
  } catch (e) {
    throw e
  }

  if (!addresses || Object.keys(addresses).length === 0) {
    return {
      BOND_NFT_ADDRESS: null,
      CHICKEN_BOND_MANAGER_ADDRESS: null,
      SLUSD_TOKEN_ADDRESS: null
    };
  }

  return addresses;
}
