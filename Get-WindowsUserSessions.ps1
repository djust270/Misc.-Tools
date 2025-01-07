function Get-WindowsUserSessions {
param(
	[String]$Username,
	[String]$ComputerName = 'localhost',
	[PSCredential]$Credential
)
$typeDef = @'
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Net;
using System.Runtime.InteropServices;
using System.Security.Principal;

namespace PSLoggedOnUsers
{
    public class WindowsUserSessionInfo
    {
        public string Username { get; set; }
        public string Domain { get; set; }
        public string SID { get; set; }
        public string SessionName { get; set; }
        public int SessionId { get; set; }
        public string State { get; set; }
        public DateTime? IdleTime { get; set; }
        public DateTime? LogonTime { get; set; }
    }
    public class SessionManager
    {
        [DllImport("advapi32.dll", SetLastError = true)]
        private static extern bool LogonUser(
            string lpszUsername,
            string lpszDomain,
            string lpszPassword,
            int dwLogonType,
            int dwLogonProvider,
            out IntPtr phToken);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr hObject);
        [DllImport("wtsapi32.dll")]
        private static extern IntPtr WTSOpenServer([MarshalAs(UnmanagedType.LPStr)] string pServerName);

        [DllImport("wtsapi32.dll")]
        private static extern void WTSCloseServer(IntPtr hServer);

        [DllImport("wtsapi32.dll")]
        private static extern int WTSEnumerateSessions(
            IntPtr hServer,
            [MarshalAs(UnmanagedType.U4)] int Reserved,
            [MarshalAs(UnmanagedType.U4)] int Version,
            ref IntPtr ppSessionInfo,
            [MarshalAs(UnmanagedType.U4)] ref int pCount);

        [DllImport("wtsapi32.dll")]
        private static extern void WTSFreeMemory(IntPtr pMemory);

        [DllImport("wtsapi32.dll", CharSet = CharSet.Auto)]
        private static extern bool WTSQuerySessionInformation(
            IntPtr hServer,
            int sessionId,
            WTS_INFO_CLASS wtsInfoClass,
            out IntPtr ppBuffer,
            out uint pBytesReturned);

        [StructLayout(LayoutKind.Sequential)]
        private struct WTS_SESSION_INFO
        {
            public int SessionID;
            [MarshalAs(UnmanagedType.LPStr)]
            public string pWinStationName;
            public WTS_CONNECTSTATE_CLASS State;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
        private struct WTSINFO
        {
            public WTS_CONNECTSTATE_CLASS State;
            public int SessionId;
            public int IncomingBytes;
            public int OutgoingBytes;
            public int IncomingFrames;
            public int OutgoingFrames;
            public int IncomingCompressedBytes;
            public int OutgoingCompressedBytes;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
            public string WinStationName;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 17)]
            public string Domain;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 21)]
            public string UserName;
            public long ConnectTime;
            public long DisconnectTime;
            public long LastInputTime;
            public long LogonTime;
            public long CurrentTime;
        }

        private enum WTS_INFO_CLASS
        {
            WTSInitialProgram,
            WTSApplicationName,
            WTSWorkingDirectory,
            WTSOEMId,
            WTSSessionId,
            WTSUserName,
            WTSWinStationName,
            WTSDomainName,
            WTSConnectState,
            WTSClientBuildNumber,
            WTSClientName,
            WTSClientDirectory,
            WTSClientProductId,
            WTSClientHardwareId,
            WTSClientAddress,
            WTSClientDisplay,
            WTSClientProtocolType,
            WTSIdleTime,
            WTSLogonTime,
            WTSIncomingBytes,
            WTSOutgoingBytes,
            WTSIncomingFrames,
            WTSOutgoingFrames,
            WTSClientInfo,
            WTSSessionInfo,
            WTSSessionInfoEx,
            WTSConfigInfo,
            WTSValidationInfo,
            WTSSessionAddressV4,
            WTSIsRemoteSession
        }

        private enum WTS_CONNECTSTATE_CLASS
        {
            Active = 0,
            Connected = 1,
            ConnectQuery = 2,
            Shadow = 3,
            Disconnected = 4,
            Idle = 5,
            Listen = 6,
            Reset = 7,
            Down = 8,
            Init = 9
        }

        private const int LOGON32_PROVIDER_DEFAULT = 0;
        private const int LOGON32_LOGON_NEW_CREDENTIALS = 9;
        public static List<WindowsUserSessionInfo> GetLoggedOnUsers(string serverName, PSCredential credential = null ,string userName = null)
        {
            IntPtr token = IntPtr.Zero;
            try
            {
                // If credentials provided and it's a remote computer, create logon token
                if (credential != null && !serverName.Equals("localhost", StringComparison.OrdinalIgnoreCase))
                {
                    NetworkCredential netCred = credential.GetNetworkCredential();
                    if (!LogonUser(netCred.UserName, netCred.Domain, netCred.Password,
                        LOGON32_LOGON_NEW_CREDENTIALS, LOGON32_PROVIDER_DEFAULT, out token))
                    {
                        throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
                    }

                    using (WindowsIdentity.Impersonate(token))
                    {
                        return GetUsersWithServer(serverName, userName);
                    }
                }
                else
                {
                    return GetUsersWithServer(serverName, userName);
                }
            }
            finally
            {
                if (token != IntPtr.Zero)
                {
                    CloseHandle(token);
                }
            }
        }
        public static List<WindowsUserSessionInfo> GetUsersWithServer(string serverName, string userName = null)
        {
            IntPtr serverHandle = WTSOpenServer(serverName);
            List<WindowsUserSessionInfo> results = new List<WindowsUserSessionInfo>();

            try
            {
                IntPtr sessionInfoPtr = IntPtr.Zero;
                int sessionCount = 0;
                int retVal = WTSEnumerateSessions(serverHandle, 0, 1, ref sessionInfoPtr, ref sessionCount);

                if (retVal != 0)
                {
                    Int64 current = sessionInfoPtr.ToInt64();
                    for (int i = 0; i < sessionCount; i++)
                    {
                        WTS_SESSION_INFO si = (WTS_SESSION_INFO)Marshal.PtrToStructure((IntPtr)current, typeof(WTS_SESSION_INFO));
                        current += Marshal.SizeOf(typeof(WTS_SESSION_INFO));
                        
                        WindowsUserSessionInfo user = new WindowsUserSessionInfo
                        {
                            SessionId = si.SessionID,
                            SessionName = si.pWinStationName,
                            State = si.State.ToString()
                        };

                        // Get username and session info
                        IntPtr buffer;
                        uint bytesReturned;
                        if (WTSQuerySessionInformation(serverHandle, si.SessionID, WTS_INFO_CLASS.WTSSessionInfo,
                            out buffer, out bytesReturned))
                        {
                            WTSINFO sessionInfo = (WTSINFO)Marshal.PtrToStructure(buffer, typeof(WTSINFO));
                            user.Username = sessionInfo.UserName;
                            user.Domain = sessionInfo.Domain;

                            if (sessionInfo.LogonTime != 0)
                            {
                                user.LogonTime = DateTime.FromFileTime(sessionInfo.LogonTime);
                            }

                            WTSFreeMemory(buffer);
                        }

                        // Get idle time
                        if (WTSQuerySessionInformation(serverHandle, si.SessionID, WTS_INFO_CLASS.WTSIdleTime,
                            out buffer, out bytesReturned))
                        {
                            uint idleTime = (uint)Marshal.ReadInt32(buffer);
                            if (idleTime != 0)
                            {
                                user.IdleTime = DateTime.Now.AddMilliseconds(-idleTime);
                            }
                            WTSFreeMemory(buffer);
                        }

                        if (!string.IsNullOrEmpty(user.Username))
                        {
                            // Construct ntAccount https://learn.microsoft.com/en-us/dotnet/api/system.security.principal.ntaccount.-ctor?view=netframework-4.7.2
                            NTAccount ntAccount = new NTAccount (user.Domain, user.Username);
                            SecurityIdentifier sid = (SecurityIdentifier)ntAccount.Translate(typeof(SecurityIdentifier));
                            string sidValue = sid.Value;
                            user.SID = sidValue;
                            results.Add(user);
                        }
                    }
                    WTSFreeMemory(sessionInfoPtr);
                }
            }
            finally
            {
                WTSCloseServer(serverHandle);
            }

            if (!string.IsNullOrEmpty(userName))
            {
                return results.Where(user => string.Equals(user.Username, userName, StringComparison.OrdinalIgnoreCase)).ToList();

            }
            else
            {
                return results;
            }
        }
    }
}
'@
Add-Type -TypeDefinition $typeDef -Language CSharp
[PSLoggedOnUsers.SessionManager]::GetLoggedOnUsers($ComputerName, $Credential, $Username)
}