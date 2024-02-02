// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, stdError} from "forge-std/Test.sol";
import {GenericFactory} from "src/GenericFactory/GenericFactory.sol";

import {MockEVault} from "../../mocks/MockEVault.sol";
import {MockRiskManager} from "../../mocks/MockRiskManager.sol";
import {TestERC20} from "../../mocks/TestERC20.sol";
import {ReentrancyAttack} from "../../mocks/ReentrancyAttack.sol";

contract FactoryTest is Test {
    GenericFactory public factory;
    address public upgradeAdmin;
    address public otherAccount;

    function setUp() public {
        address admin = vm.addr(1000);

        vm.expectEmit();
        emit GenericFactory.Genesis();

        vm.expectEmit(true, false, false, false);
        emit GenericFactory.SetUpgradeAdmin(admin);

        factory = new GenericFactory(admin);

        // Defaults are all set to admin
        assertEq(factory.upgradeAdmin(), admin);

        // Implementation starts at address(0)
        assertEq(factory.implementation(), address(0));

        upgradeAdmin = vm.addr(1000);
        otherAccount = vm.addr(1001);

        vm.prank(admin);
        factory.setUpgradeAdmin(upgradeAdmin);

        // Newly set values
        assertEq(factory.upgradeAdmin(), upgradeAdmin);
    }

    function test_setImplementationSimple() public {
        vm.prank(upgradeAdmin);
        factory.setImplementation(address(1));
        assertEq(factory.implementation(), address(1));

        vm.prank(upgradeAdmin);
        factory.setImplementation(address(2));
        assertEq(factory.implementation(), address(2));
    }

    function test_activateMarket() public {
        // Create and install mock eVault impl
        MockEVault mockEvaultImpl = new MockEVault(address(factory), address(1));
        vm.prank(upgradeAdmin);
        factory.setImplementation(address(mockEvaultImpl));

        // Create token and activate it
        TestERC20 asset = new TestERC20("Test Token", "TST", 17, false);
        MockRiskManager rm = new MockRiskManager();

        MockEVault eTST = MockEVault(factory.createProxy(true, abi.encodePacked(address(asset), address(rm))));

        // Verify proxying behaves as intended
        assertEq(eTST.implementation(), "TRANSPARENT");

        {
            string memory inputArg = "hello world! 12345678900987654321";

            address randomUser = vm.addr(5000);
            vm.prank(randomUser);
            (string memory outputArg, address theMsgSender, address marketAsset, address riskManager) =
                eTST.arbitraryFunction(inputArg);

            assertEq(outputArg, inputArg);
            assertEq(theMsgSender, randomUser);
            assertEq(marketAsset, address(asset));
            assertEq(riskManager, address(rm));
        }
    }

    function test_getEVaultsListLength() public {
        // Create and install mock eVault impl
        MockEVault mockEvaultImpl = new MockEVault(address(factory), address(1));
        vm.prank(upgradeAdmin);
        factory.setImplementation(address(mockEvaultImpl));
        MockRiskManager rm = new MockRiskManager();

        // Create Tokens and activate Markets
        uint256 amountEVault = 10;
        for (uint256 i; i < amountEVault; i++) {
            TestERC20 TST = new TestERC20("Test Token", "TST", 18, false);
            MockEVault(factory.createProxy(true, abi.encodePacked(address(TST), address(rm))));
        }

        uint256 lenEVaultList = factory.getProxyListLength();

        assertEq(lenEVaultList, amountEVault);
    }

    function test_getEVaultsList() public {
        // Create and install mock eVault impl
        MockEVault mockEvaultImpl = new MockEVault(address(factory), address(1));
        vm.prank(upgradeAdmin);
        factory.setImplementation(address(mockEvaultImpl));
        MockRiskManager rm = new MockRiskManager();

        // Create Tokens and activate Markets
        uint256 amountEVaults = 100;

        address[] memory eVaultsList = new address[](amountEVaults);

        for (uint256 i; i < amountEVaults; i++) {
            TestERC20 TST = new TestERC20("Test Token", "TST", 18, false);
            MockEVault eVault = MockEVault(factory.createProxy(true, abi.encodePacked(address(TST), address(rm))));
            eVaultsList[i] = address(eVault);
        }

        //get eVaults List
        address[] memory listEVaultsTest;
        address[] memory listGenericFactory;

        //test getEVaultsList(0, type(uint).max) - get all eVaults list
        uint256 startIndex = 0;
        uint256 endIndex = type(uint256).max;

        listGenericFactory = factory.getProxyListSlice(startIndex, endIndex);

        listEVaultsTest = eVaultsList;

        assertEq(listGenericFactory, listEVaultsTest);

        //test getEVaultsList(3, 10) - get [3,10) slice
        startIndex = 3;
        endIndex = 10;

        listGenericFactory = factory.getProxyListSlice(startIndex, endIndex);

        listEVaultsTest = new address[](endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            listEVaultsTest[i - startIndex] = eVaultsList[i];
        }

        assertEq(listGenericFactory, listEVaultsTest);
    }

    function test_getEVaultConfig() public {
        // Create and install mock eVault impl
        MockEVault mockEvaultImpl = new MockEVault(address(factory), address(1));
        vm.prank(upgradeAdmin);
        factory.setImplementation(address(mockEvaultImpl));
        MockRiskManager rm = new MockRiskManager();

        // Create Tokens and activate Markets
        TestERC20 TST = new TestERC20("Test Token", "TST", 18, false);
        MockEVault eVault = MockEVault(factory.createProxy(true, abi.encodePacked(address(TST), address(rm))));

        GenericFactory.ProxyConfig memory config = factory.getProxyConfig(address(eVault));

        assertEq(config.trailingData, abi.encodePacked(address(TST), address(rm)));

        TST = new TestERC20("Test Token", "TST", 18, false);
        eVault = MockEVault(factory.createProxy(true, abi.encodePacked(address(TST), address(rm))));

        config = factory.getProxyConfig(address(eVault));

        assertEq(config.trailingData, abi.encodePacked(address(TST), address(rm)));
    }

    function test_Event_ProxyCreated() public {
        // Create and install mock eVault impl
        MockEVault mockEvaultImpl = new MockEVault(address(factory), address(1));
        vm.prank(upgradeAdmin);
        factory.setImplementation(address(mockEvaultImpl));

        // Create token and activate it
        TestERC20 asset = new TestERC20("Test Token", "TST", 17, false);
        MockRiskManager rm = new MockRiskManager();

        vm.expectEmit(false, true, true, true);
        emit GenericFactory.ProxyCreated(
            address(1), true, address(mockEvaultImpl), abi.encodePacked(address(asset), address(rm))
        );

        factory.createProxy(true, abi.encodePacked(address(asset), address(rm)));
    }

    function test_Event_SetEVaultImplementation() public {
        vm.expectEmit(true, false, false, false);
        emit GenericFactory.SetImplementation(address(1));

        vm.prank(upgradeAdmin);
        factory.setImplementation(address(1));
    }

    function test_Event_SetUpgradeAdmin() public {
        address newUpgradeAdmin = vm.addr(1002);

        vm.expectEmit(true, false, false, false, address(factory));
        emit GenericFactory.SetUpgradeAdmin(newUpgradeAdmin);

        vm.prank(upgradeAdmin);
        factory.setUpgradeAdmin(newUpgradeAdmin);
    }

    function test_RevertIfUnauthorized() public {
        // Nobody addresses are unauthorised

        vm.prank(vm.addr(2000));
        vm.expectRevert(GenericFactory.E_Unauthorized.selector);
        factory.setUpgradeAdmin(address(1));

        // Only upgradeAdmin can upgrade
        vm.prank(otherAccount);
        vm.expectRevert(GenericFactory.E_Unauthorized.selector);
        factory.setImplementation(address(1));
    }

    function test_RevertIfNonReentrancy_ActivateMarket() public {
        ReentrancyAttack badVaultImpl = new ReentrancyAttack(address(factory), address(1));
        vm.prank(upgradeAdmin);
        factory.setImplementation(address(badVaultImpl));

        address asset = vm.addr(1);
        address rm = vm.addr(2);

        vm.expectRevert(GenericFactory.E_Reentrancy.selector);
        factory.createProxy(false, abi.encodePacked(address(asset), address(rm)));
    }

    function test_RevertIfImplementation_ActivateMarket() public {
        address rm = vm.addr(2);
        address asset = vm.addr(1);

        vm.expectRevert(GenericFactory.E_Implementation.selector);
        factory.createProxy(true, abi.encodePacked(address(asset), address(rm)));
    }

    function test_RevertIfBadAddress() public {
        vm.prank(upgradeAdmin);
        vm.expectRevert(GenericFactory.E_BadAddress.selector);
        factory.setImplementation(address(0));

        vm.prank(upgradeAdmin);
        vm.expectRevert(GenericFactory.E_BadAddress.selector);
        factory.setUpgradeAdmin(address(0));
    }

    function test_RevertIfErrorList_GetEVaultsList() public {
        // Create and install mock eVault impl
        MockEVault mockEvaultImpl = new MockEVault(address(factory), address(1));
        vm.prank(upgradeAdmin);
        factory.setImplementation(address(mockEvaultImpl));
        MockRiskManager rm = new MockRiskManager();

        // Create Tokens and activate Markets
        uint256 amountEVaults = 100;

        address[] memory eVaultsList = new address[](amountEVaults);

        for (uint256 i; i < amountEVaults; i++) {
            TestERC20 TST = new TestERC20("Test Token", "TST", 18, false);
            MockEVault eVault = MockEVault(factory.createProxy(true, abi.encodePacked(address(TST), address(rm))));
            eVaultsList[i] = address(eVault);
        }

        vm.expectRevert(GenericFactory.E_BadQuery.selector);
        factory.getProxyListSlice(0, eVaultsList.length + 1);

        vm.expectRevert(GenericFactory.E_BadQuery.selector);
        factory.getProxyListSlice(50, eVaultsList.length + 1);

        vm.expectRevert(GenericFactory.E_BadQuery.selector);
        factory.getProxyListSlice(1, 0);

        vm.expectRevert(GenericFactory.E_BadQuery.selector);
        factory.getProxyListSlice(1000, 1000);
    }

    // TODO test non-upgradeable
}