# EMA Buffs

A Gemini-generated plugin for **EMA (Ebony's MultiBoxing Assistant)** [https://www.curseforge.com/wow/addons/ema](https://www.curseforge.com/wow/addons/ema). This addon provides persistent, team-wide buff tracking for all character classes, with a special focus on integration with your team's cooldown bars.

Looking for other team-wide tracking? Check out [EMA Cooldowns](https://github.com/Quiding/ema_cooldowns) or Shaman-specific [EMA Totems](https://github.com/Quiding/ema_totems).

**Note:** This addon likely requires your team to be in the same guild and utilize **guild communications** for settings synchronization.

**Disclaimer:** These addons are early-stage Gemini-generated prototypes and have not undergone extensive bug testing. Please use with caution and report any issues you find.

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


## Export example
*  Tracked Buffs List ( Just Water Shield for Shamans )
  ```^1^T^SHUNTER^T^t^SWARRIOR^T^t^SPALADIN^T^t^SMAGE^T^t^SPRIEST^T^t^SWARLOCK^T^t^SROGUE^T^t^SDRUID^T^t^SDEATHKNIGHT^T^t^SSHAMAN^T^N1^T^Sid^N23575^Sname^SWater~`Shield^Sicon^N132315^t^t^t^^```
*  Settings & Positions ( Buffs integrated into Cooldowns )  ```^1^T^SlockBars^b^SglowColorB^F8548009268740096^f-53^SbarMargin^N4^SglowColorG^F8406719877087232^f-53^SstackColorG^N1^SframeBackgroundColourG^N0.1^SmissingAlpha^N1^SframeBorderColourR^N0.5^SintegrateWithCooldowns^B^Sglobal^T^t^SintegratePosition^SRight^SrunningAlpha^N0.3^SbarScale^N1.2^SframeBorderColourG^N0.5^SframeBorderStyle^SBlizzard~`Tooltip^SbarAlpha^N1^SiconSize^N38^SbarBorderStyle^SBlizzard~`Tooltip^SfontSize^N12^SglowIfMissing^B^SbarBorderColourA^N1^SfontStyle^SArial~`Narrow^SbarBackgroundColourG^N0.1^SbarBorderColourG^N0.5^SbarBorderColourB^N0.5^SglowColorA^N1^SshowBars^B^SbarOrder^SRoleAsc^SglowAnimated^B^SbarBackgroundColourR^N0.1^SstackColorR^N1^SbarBackgroundColourA^N0.7^SframeBorderColourA^N1^SglowColorR^N1^SbarBorderColourR^N0.5^SbarBackgroundColourB^N0.1^SframeBackgroundColourB^N0.1^SframeBackgroundStyle^SBlizzard~`Dialog~`Background^SshowNames^B^SframeBackgroundColourA^N0.7^SframeBorderColourB^N0.5^SbarLayout^SHorizontal^SiconMargin^N15^SframeBackgroundColourR^N0.1^SstackColorB^N0^SbarBackgroundStyle^SBlizzard~`Dialog~`Background^SstackFontSize^N12^SbreakUpBars^b^t^^```
