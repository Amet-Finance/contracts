import {deployIssuer, deployVault} from "./utils/deploy";

describe("Bond", () => {


    let bond;

    before(async () => {
        const issuer = await deployIssuer();
        const vault = await deployVault(issuer.target);
        await issuer.changeVault(vault.target);

        // bond = issuer.issue();
    })


    it("URI", () => {

    })
})
