# EMA Buffs

A Gemini-generated plugin for **EMA (Ebony's MultiBoxing Assistant)** [https://www.curseforge.com/wow/addons/ema](https://www.curseforge.com/wow/addons/ema). This addon provides persistent, team-wide buff tracking for all character classes, with a special focus on integration with your team's cooldown bars.

Looking for other team-wide tracking? Check out [EMA Cooldowns](https://github.com/Quiding/ema_cooldowns) or Shaman-specific [EMA Totems](https://github.com/Quiding/ema_totems).

**Note:** This addon likely requires your team to be in the same guild and utilize **guild communications** for settings synchronization.

Is this AI slop? probably, but it seems to work

## Key Features

*   **Persistent Buff Tracking:** Monitor tracked buffs across your entire team in one compact interface.
*   **Cooldowns Integration:** Seamlessly integrate your buff icons directly onto your [EMA Cooldowns](https://github.com/Quiding/ema_cooldowns) bars, with customizable positioning (Left or Right side).
*   **Animated Activation Border:** Optional animated "marching ants" glow for missing buffs, utilizing `LibButtonGlow-1.0` for a high-visibility alert.
*   **Customizable Opacity:** Separate opacity settings for active timers ("Running Opacity") and missing buffs ("Missing Opacity").
*   **Flexible Layouts:** Choose between a standalone master frame or attached to your cooldown bars. Customize scales, margins, and sorting orders (Name, Role, or EMA Team Position).
*   **Class-Specific Tracking:** Easily add, remove, and reorder buffs for every class to match your team's specific requirements.
*   **Team Synchronization:** Push your configuration and tracked buff lists from the master to the entire team with a single click.

## Installation

1.  Download the repository.
2.  Save the folder as **"EMA_Buffs"** in your `Interface\AddOns` directory.
3.  Ensure **EMA** is installed and enabled.

## Usage

*   Open the EMA configuration menu and navigate to **Class > Buffs**.
*   Toggle **Integrate into Cooldowns bar** to merge the UIs, or keep them separate.
*   Use **Select Class to Manage** to customize the specific buffs you want to track.
*   Adjust the **Glow if missing** and **Glow Animation** settings to your preference for visual alerts.
*   Use the command `/ebf config` to open the settings directly.
