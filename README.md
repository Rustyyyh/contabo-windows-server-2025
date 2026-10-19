# Windows Server 2025 on a Contabo VPS

Install **Windows Server 2025** on your Contabo VPS with one script. No ISO uploads and no tricky setup: the script downloads everything for you.

> [!WARNING]
> This **deletes everything** on your VPS. Save anything you need before you start.

## What you need

- A Contabo VPS (at least 50 GB of disk)
- A VNC viewer, such as [RealVNC Viewer](https://www.realvnc.com/en/connect/download/viewer/) (free)
- About 30-45 minutes

## Installation

Follow these steps in order.

**Prepare the VPS**

1. Log in to the Contabo control panel.
2. Find your VPS and click **Manage → Rescue System**.
3. Choose the newest **Debian** version, set a password and click **Start**. Wait about a minute.

**Run the script**

4. On your PC, open **PowerShell** (on Mac or Linux: **Terminal**).
5. Connect to your VPS (replace `YOUR_VPS_IP` with your VPS IP address):
   ```sh
   ssh root@YOUR_VPS_IP
   ```
6. If asked, type `yes`. Then type the password from step 3 (it stays invisible while you type) and press Enter.
7. Copy and paste these two lines and press Enter:
   ```sh
   wget https://raw.githubusercontent.com/Rustyyyh/contabo-windows-server-2025/main/install.sh
   bash install.sh
   ```
8. When asked, type `YES` and press Enter. Wait 15-30 minutes.
9. When it says **Ready**, write down the **IP address** and **gateway** it shows. Press Enter: the VPS restarts.

**Install Windows**

10. In the Contabo panel, click **Manage → VNC Information**. Note the address and port, and set a VNC password.
11. Open your VNC viewer and connect to that address. You will see the Windows installer.
12. Choose your language and keyboard, then click **Next** and **Install**.
13. On the screen **Install driver to show hardware**, click **Browse**, choose `X:\virtio` and click **OK**.
14. Select **all** the drivers in the list and click **Install**.
15. Choose **Windows Server 2025 Standard Evaluation (Desktop Experience)** and click **Next**.
16. Accept the license terms.
17. Choose **Unallocated Space** and click **Next**.
18. Wait while Windows installs. The VPS restarts a few times by itself.
19. Choose a password for **Administrator** and click **Finish**.

**Connect to your server**

20. On your Windows PC, press **Win+R**, type `mstsc` and press Enter.
21. Type your VPS IP address and click **Connect**.
22. Log in as `Administrator` with the password from step 19.

Done. Enjoy your Windows Server.

## Something went wrong?

**The screen says "Press Ctrl+Alt+Delete" and nothing happens**
Your own PC catches that key combination. In RealVNC, press **F8** inside the VNC window and choose **Send Ctrl+Alt+Del** (or use the button in the top toolbar).

**The mouse pointer does not follow your mouse in VNC**
Press **Win+R**, type `main.cpl` and press Enter. In **Pointer Options**, uncheck **Enhance pointer precision** and click OK. Then move the mouse to the top-left corner to realign it.

**There is no `X:\virtio` folder, or you get error `0x80070103`**
Repeat steps 1-6, then run:
```sh
wget https://raw.githubusercontent.com/Rustyyyh/contabo-windows-server-2025/main/install.sh
bash install.sh --repair-drivers
```
Nothing is deleted. The VPS restarts and you can continue from step 10.

**Remote Desktop does not connect**
Open the VNC console, go to **Settings → System → Remote Desktop** and turn it on.

**No internet in Windows**
The network is set up automatically, but if it does not work, set it by hand. Open the VNC console, open **Terminal**, type `sconfig` and press Enter. Then type `8`, the number of your network adapter, and:
- `1`, then `S`, then the IP address, subnet mask `255.255.255.0` and the gateway you wrote down in step 9;
- `2`, then DNS servers `1.1.1.1` and `8.8.8.8`.

## Good to know

- This is the free **evaluation** version of Windows Server, valid for **180 days**. To keep using it, activate it with your own license key.
- About 14 GB of the disk is kept for the Windows startup files.
- Use it at your own risk.

## License

[MIT](LICENSE)
