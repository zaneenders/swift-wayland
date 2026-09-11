# Chroma over SSH

Status: proposed design. The SSH server, configuration format, and Chroma CLI
commands below are not implemented yet. The current remote prototype uses TCP.

## Vision

Make SSH a first-class entry point to a native Chroma application, inspired by
SSH destinations such as `terminal.shop`. Connecting to an endpoint should feel
like visiting a website, not manually setting up a tunnel.

The proposed experience is:

```sh
chroma ssh user@example.com -p 42069
```

A Chroma-capable client authenticates to the endpoint and opens a native window:

- The server owns application state, the block graph, interaction, layout, and
  drawing-command generation.
- The client owns the native window, GPU rendering, and input collection.
- SSH provides endpoint identity, user authentication, encryption, and a
  bidirectional transport for the Chroma protocol.

A normal terminal SSH client cannot render this native UI on its own. Chroma
needs its own client, just as a website needs a browser.

## Deployment decision

Build a standalone application SSH server using `swift-nio-ssh`, listening on
TCP port **42069** by default. Do not require an existing OpenSSH daemon, OS user
accounts for application users, or a separate publicly exposed Chroma TCP port.

Run the service under a dedicated, unprivileged OS account. Port 42069 does not
require privileged binding. Public deployments must explicitly configure their
firewall and listen address; the example below binds all IPv4 interfaces.

The SSH implementation supplies protocol machinery. Account storage, key
approval, authentication policy, permissions, and resource limits remain Chroma
server responsibilities.

An OpenSSH subsystem adapter can be added later for installations that want to
reuse existing machine accounts. It is not the primary deployment model.

## Identities and credentials

Keep three concepts separate:

| Concept | Responsibility |
| --- | --- |
| Server host key | Proves the identity of the Chroma endpoint. |
| User public key | Identifies an approved credential; SSH verifies possession of its private key. |
| Application permissions | Determine what the authenticated user may do. |

Application users are not operating-system users. Authenticating grants access
to the application, never an operating-system shell.

The server stores its host private key and users' public keys. User private keys
remain on their devices or in their SSH agents and must never be uploaded to the
service.

### Initial user store

Use a small administrator-managed configuration file for v1. A database is not
required initially. This TOML is an illustrative schema, not an existing API:

```toml
[server]
listen = "0.0.0.0:42069"
host_key = "/var/lib/chroma/ssh_host_ed25519_key"

[users.zane]
roles = ["admin"]
authorized_keys = [
  "ssh-ed25519 AAAA... laptop",
  "ssh-ed25519 AAAA... desktop",
]

[users.guest]
roles = ["viewer"]
authorized_keys = [
  "ssh-ed25519 AAAA... guest-laptop",
]
```

The key strings above are placeholders, not valid keys. `guest` is an ordinary
registered account in this example, not an anonymous-access mechanism.

Each user needs:

- A stable identity; a unique username is sufficient initially.
- Multiple approved keys so devices can be managed independently.
- Explicit application roles or permissions.
- Account disabling and individual-key revocation.

Parse and validate keys when loading configuration. Compare actual key material,
not comments, and reject assigning the same key to different users initially.
Reject invalid configuration atomically rather than partially applying it.
Protect the file from writes by unauthorized users: it controls access even
though public keys themselves are not secrets.

The authentication delegate approves only configured, enabled username/key
pairs. SSH must complete cryptographic proof of private-key possession before
creating an authenticated application session. Merely presenting an approved
public key is not sufficient.

Attach the authenticated principal to the session. Enforce permissions in
server-side application operations, not just by hiding UI controls or trusting
usernames and roles in client messages. Role names such as `viewer` and `admin`
need explicit meanings in the hosted application; Chroma cannot infer them.

### Enrollment

Start with administrator-approved enrollment:

1. A user creates a dedicated SSH key or selects an existing compatible key.
2. They send the administrator only the public key.
3. The administrator verifies the intended account and approves the key.
4. The user connects using their private key or SSH agent.

For example, generate a dedicated Ed25519 key and use a passphrase:

```sh
ssh-keygen -t ed25519 \
  -f ~/.ssh/chroma_ed25519 \
  -C "zane-chroma"
```

The `.pub` file is shareable. The file without `.pub` is private.

Do not automatically register arbitrary presented keys or introduce password
storage in v1.

### Revocation and rotation

- Support adding a replacement device key before removing the old one.
- Reload configuration so revoked keys and disabled accounts cannot establish
  new sessions.
- Provide an administrative operation to terminate active sessions belonging to
  a revoked key or disabled account.
- Track the authenticated user and key fingerprint per connection so revocation
  can target the correct sessions.
- Define how role changes affect active sessions; do not leave permissions stale
  indefinitely. Terminating affected sessions is an acceptable v1 policy.

Never log private keys, authentication secrets, or raw application payloads.
Operational logs can record authentication outcomes, users, public-key
fingerprints, and session lifecycle events with an appropriate retention policy.

## Server host identity

Generate a persistent Ed25519 host key during initial setup. Store it with
owner-only permissions and retain it across restarts, upgrades, and deployments.
Do not generate a new key on every launch or bake one shared private key into a
distributed image.

The client must:

- Show the host-key fingerprint when first connecting to an unknown endpoint.
- Require explicit acceptance, or use an administrator-provided trusted key.
- Remember the accepted identity for the hostname and port.
- Reject a changed key with a clear warning rather than silently accepting it.
- Support preconfigured fingerprints or known-host entries for managed use.

Publish the initial fingerprint through a trusted channel. Trust on first use
without independent verification retains ordinary SSH's first-connection
impersonation risk. Host-key rotation needs an explicit operational procedure.

## SSH session contract

Use an SSH session channel and request a named **`chroma` subsystem**, rather
than allocating a terminal or invoking a shell command. The standalone server
handles this request itself; it does not need an OpenSSH `Subsystem` setting.

For reference, the equivalent request with an ordinary SSH executable is:

```sh
ssh -T -p 42069 -s user@example.com chroma
```

That command is a transport illustration, not a usable terminal UI: the
subsystem exchanges binary Chroma messages.

Allow initially:

- Public-key authentication, starting with Ed25519 credentials.
- One Chroma session per authenticated connection.
- Only the Chroma protocol within the accepted subsystem channel.

Reject:

- Password and anonymous authentication.
- Shell and arbitrary command execution requests.
- PTY allocation.
- TCP forwarding in either direction.
- Agent and X11 forwarding.
- SFTP and unrelated subsystems.
- Unsupported channel types and extra sessions.

Local SSH-agent use for client authentication is distinct from agent forwarding:
the client may use an agent without exposing it to the server.

Start with one application instance per authenticated session. Disconnect ends
that instance and releases resources. Durable state, shared application state,
and resumable sessions require explicit application/session policies; a new SSH
connection must not implicitly inherit an old session.

## Client implementation

A standalone `swift-nio-ssh` server can interoperate with the system OpenSSH
client. Prefer system OpenSSH for the initial Chroma client transport so existing
SSH configuration, agent authentication, jump hosts, and known-host verification
can be reused.

For example, users could configure:

```sshconfig
Host my-chroma
    HostName example.com
    Port 42069
    User zane
    IdentityFile ~/.ssh/chroma_ed25519
    IdentitiesOnly yes
    ForwardAgent no
```

Then the proposed command becomes:

```sh
chroma ssh my-chroma
```

The Chroma client owns the SSH subprocess and exchanges framed protocol bytes
through its stdin/stdout. Keep stderr separate from protocol data. Handle host
verification and authentication prompts deliberately, propagate errors, and
clean up the child process when the client closes. Do not disable host-key
checking to make integration easier.

An embedded `swift-nio-ssh` client is a later option. It would need explicit
implementations for credential selection, agent integration, host verification,
and any supported SSH configuration behavior; these are not automatic library
features.

## Chroma protocol and library changes

The existing `RemoteMetalClient` and `RemoteServer` directly establish TCP
connections. Separate transport establishment from the protocol/session logic
so TCP, SSH channels, and client subprocess pipes can share framing and session
behavior.

Keep the existing rendering/input message model where practical. Add an initial
handshake to negotiate:

- Protocol version.
- Supported capabilities.
- Message and frame limits.

Reject incompatible peers with a useful error before normal frame exchange.
Treat SSH channels and pipes as byte streams: messages may be fragmented or
coalesced. Preserve bounded buffering, backpressure, and cancellation rather
than assuming writes map one-to-one to reads.

The first implementation should establish this end-to-end flow:

```text
Chroma native client
    ↕ local subprocess pipes
System SSH client
    ↕ encrypted SSH connection to TCP 42069
Standalone Chroma SSH server
    ↕ authenticated chroma subsystem channel
Per-session Chroma application
```

No Chroma TCP forwarding or separately listening per-session backend is needed.

## Security and resource boundaries

SSH authenticates endpoints and protects transport. It does not make a remote
application trustworthy or replace protocol validation.

Before public exposure:

- Apply connection, authentication-attempt, and concurrent-session limits.
- Enforce authentication and protocol-handshake timeouts.
- Rate-limit abuse and release unauthenticated connection resources promptly.
- Bound messages, decoded images, frame complexity, buffering, and queued work.
- Enforce clipboard policy on the client, including user control over remote
  reads and writes.
- Never allow protocol messages to execute arbitrary local commands.
- Keep keys and server configuration outside application-controlled writes.
- Define isolation appropriate to the hosted application. An SSH channel is not
  a sandbox for server-side code.

## Future public access and account management

A website-like public app may eventually offer anonymous sessions. That must be
an explicit, separately scoped policy with strict permissions and resource
limits, not an accidental fallback after failed authentication. An SSH username
alone is not an identity claim the server can trust.

A later enrollment flow could use an authenticated signup or one-time invitation
and require proof of possession of the registered key. SSH certificates may be
useful once many users and endpoints make individual approved-key lists costly;
they are outside v1 and depend on implementation support.

Other deferred work includes persistent/resumable sessions, a database-backed
user store, embedded client SSH, and an OpenSSH subsystem deployment adapter.

## Implementation milestones

1. Extract transport-independent remote session/framing setup; retain TCP for
   existing local operation and tests.
2. Implement the standalone SSH listener on port 42069, persistent host identity,
   validated user/key configuration, and public-key-only authentication.
3. Accept only the `chroma` subsystem and attach an authenticated principal to a
   per-session application instance.
4. Add protocol negotiation and the system-SSH-backed native client connection.
5. Implement revocation, cleanup, resource limits, and useful connection errors.
6. Test correct and incorrect keys, disabled users, unsupported SSH requests,
   changed host keys, protocol mismatch, fragmented messages, disconnect cleanup,
   concurrent-user separation, and active-session revocation.

The v1 outcome is a native UI destination hosted directly over SSH: application
users and approved public keys, no OS-account provisioning, no shell access, and
no user-managed tunnel.
