
import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;
const deployer = accounts.get("deployer")!;

describe("Verified Artisan Registry - Skills Assessment System", () => {
  it("ensures simnet is well initialised", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  describe("Core Functionality Tests", () => {
    it("should allow creating a new skill category", () => {
      const { result } = simnet.callPublicFn(
        "Verified-Artisan-Registry",
        "create-skill",
        [
          Cl.stringAscii("Woodworking"),
          Cl.stringAscii("Advanced woodworking techniques including joinery and finishing"),
          Cl.stringAscii("Craftsmanship"),
          Cl.uint(3), // difficulty level
          Cl.uint(80) // passing score
        ],
        address1
      );
      expect(result).toBeOk(Cl.uint(1));
    });

    it("should retrieve skill information", () => {
      // First create a skill
      simnet.callPublicFn(
        "Verified-Artisan-Registry",
        "create-skill",
        [
          Cl.stringAscii("Pottery"), 
          Cl.stringAscii("Ceramic arts and pottery techniques"), 
          Cl.stringAscii("Craftsmanship"), 
          Cl.uint(2), 
          Cl.uint(75)
        ],
        address1
      );

      const { result } = simnet.callReadOnlyFn(
        "Verified-Artisan-Registry",
        "get-skill",
        [Cl.uint(1)],
        address1
      );
      expect(result).toBeSome();
    });

    it("should allow artisan registration and skill assessment", () => {
      // First register artisan
      const registerResult = simnet.callPublicFn(
        "Verified-Artisan-Registry",
        "register-artisan",
        [
          Cl.stringAscii("John Smith"), 
          Cl.stringAscii("Woodworker"), 
          Cl.stringAscii("New York")
        ],
        address2
      );
      expect(registerResult.result).toBeOk(Cl.uint(1));

      // Create a skill
      simnet.callPublicFn(
        "Verified-Artisan-Registry",
        "create-skill",
        [
          Cl.stringAscii("Carving"), 
          Cl.stringAscii("Wood carving techniques"), 
          Cl.stringAscii("Woodworking"), 
          Cl.uint(3), 
          Cl.uint(70)
        ],
        address1
      );

      // Take assessment
      const { result } = simnet.callPublicFn(
        "Verified-Artisan-Registry",
        "take-assessment",
        [
          Cl.uint(1), // artisan-id
          Cl.uint(1), // skill-id
          Cl.uint(85), // score
          Cl.uint(100) // max-score
        ],
        address2
      );
      expect(result).toBeOk(Cl.uint(1));
    });

    it("should return skills statistics", () => {
      const { result } = simnet.callReadOnlyFn(
        "Verified-Artisan-Registry",
        "get-skills-stats",
        [],
        address1
      );
      expect(result).toBeTuple();
    });

    it("should calculate artisan skill score", () => {
      // Register artisan first
      simnet.callPublicFn(
        "Verified-Artisan-Registry",
        "register-artisan",
        [
          Cl.stringAscii("Skilled Artisan"), 
          Cl.stringAscii("Multi-talented"), 
          Cl.stringAscii("Skill City")
        ],
        address1
      );

      const { result } = simnet.callReadOnlyFn(
        "Verified-Artisan-Registry",
        "calculate-artisan-skill-score",
        [Cl.uint(1)],
        address1
      );
      expect(result).toBeOk();
    });

    it("should check certification validity", () => {
      // Register artisan and create skill
      simnet.callPublicFn(
        "Verified-Artisan-Registry",
        "register-artisan",
        [
          Cl.stringAscii("Test Artisan"), 
          Cl.stringAscii("Tester"), 
          Cl.stringAscii("Test City")
        ],
        address1
      );

      simnet.callPublicFn(
        "Verified-Artisan-Registry",
        "create-skill",
        [
          Cl.stringAscii("Test Skill"), 
          Cl.stringAscii("Test skill description"), 
          Cl.stringAscii("Testing"), 
          Cl.uint(1), 
          Cl.uint(80)
        ],
        address2
      );

      // Take assessment with passing score
      simnet.callPublicFn(
        "Verified-Artisan-Registry",
        "take-assessment",
        [Cl.uint(1), Cl.uint(1), Cl.uint(85), Cl.uint(100)],
        address1
      );

      // Check certification validity
      const { result } = simnet.callReadOnlyFn(
        "Verified-Artisan-Registry",
        "is-certification-valid",
        [Cl.uint(1), Cl.uint(1)],
        address1
      );
      expect(result).toBeBool(true);
    });
  });

  describe("Error Handling", () => {
    it("should enforce valid difficulty levels", () => {
      const { result } = simnet.callPublicFn(
        "Verified-Artisan-Registry",
        "create-skill",
        [
          Cl.stringAscii("Invalid Skill"), 
          Cl.stringAscii("Invalid difficulty"), 
          Cl.stringAscii("Test"), 
          Cl.uint(6), // Invalid difficulty level > 5
          Cl.uint(80)
        ],
        address1
      );
      expect(result).toBeErr(Cl.uint(423)); // ERR-INVALID-SKILL-LEVEL
    });

    it("should prevent non-admin from deactivating skill", () => {
      // Create skill
      simnet.callPublicFn(
        "Verified-Artisan-Registry",
        "create-skill",
        [
          Cl.stringAscii("Protected Skill"), 
          Cl.stringAscii("Skill protected from deactivation"), 
          Cl.stringAscii("Security"), 
          Cl.uint(3), 
          Cl.uint(80)
        ],
        address1
      );

      // Try to deactivate as non-admin
      const { result } = simnet.callPublicFn(
        "Verified-Artisan-Registry",
        "deactivate-skill",
        [Cl.uint(1)],
        address1
      );
      expect(result).toBeErr(Cl.uint(401)); // ERR-UNAUTHORIZED
    });
  });
});
