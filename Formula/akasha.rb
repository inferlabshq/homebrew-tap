# Rendered by scripts/brew-formula.sh in inferlabshq/akasha for v0.1.0-alpha.7.
# Do not edit by hand: the release workflow overwrites this file on every tag.
class Akasha < Formula
  desc "Local credential vault an AI agent uses one operation at a time"
  homepage "https://getakasha.dev"
  version "0.1.0-alpha.7"
  license "Apache-2.0"

  livecheck do
    url :stable
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/inferlabshq/akasha/releases/download/v0.1.0-alpha.7/akasha-darwin-arm64"
      sha256 "daba1f6f1cad2ba114ad3d75b8bfbf78b6238eb93fdaa8489174ba6ca9dd54f4"
    end
    on_intel do
      url "https://github.com/inferlabshq/akasha/releases/download/v0.1.0-alpha.7/akasha-darwin-amd64"
      sha256 "5d5527eac59c8a917ec0ee82ec15c27f6374d4c4dd10584e83516752e080c90e"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/inferlabshq/akasha/releases/download/v0.1.0-alpha.7/akasha-linux-arm64"
      sha256 "6ca7b9a69cd0d0741eab8ab2d9932e97f6066d3a7a91efdb2ad8d76593c0bc5d"
    end
    on_intel do
      url "https://github.com/inferlabshq/akasha/releases/download/v0.1.0-alpha.7/akasha-linux-amd64"
      sha256 "21583ec5d94f3a6bdba5839835e011d758be5543aed21bcea807509801a128b4"
    end
  end

  # Provider templates ship as data, not compiled in. This is the same bundle
  # (and the same checksum) install.sh verifies.
  resource "templates" do
    url "https://github.com/inferlabshq/akasha/releases/download/v0.1.0-alpha.7/akasha-templates.tar.gz"
    sha256 "421137561e2fc3e14c8cc94eabdbb71dab9dcc0a3c4de74d2bf026e5ae1044d5"
  end

  def install
    binary = Dir["akasha-*"].first
    odie "no release binary was staged" if binary.nil?
    chmod 0755, binary
    libexec.install binary => "akasha"

    # launchd will not run an unsigned binary. The release build carries the Go
    # linker's ad-hoc signature under the identifier "a.out"; re-sign ad-hoc
    # with the daemon's stable identifier, which is the fallback install.sh
    # uses. A Developer ID signature, once the release pipeline has one, is
    # left exactly as shipped.
    if OS.mac?
      # codesign -dv exits non-zero on an unsigned file; treat that as "sign it".
      sig = begin
        Utils.safe_popen_read("codesign", "-dv", "--verbose=2", libexec/"akasha", err: :out)
      rescue ErrorDuringExecution
        ""
      end
      if sig.empty? || sig.include?("Signature=adhoc")
        system "codesign", "-s", "-", "-i", "dev.akasha.daemon", "-f", libexec/"akasha"
      end
    end

    # The bundle is tar'd with a single top-level templates/ directory, which
    # Homebrew strips while staging; tolerate either layout.
    resource("templates").stage do
      src = File.directory?("templates") ? "templates" : "."
      (pkgshare/"templates").install Dir["#{src}/*.yaml"], Dir["#{src}/*.yaml.sig"]
    end

    # The launcher. The daemon reads its bundle from ~/.akasha/templates.dist
    # and Homebrew cannot write there at install time (the install sandbox is
    # confined to the prefix; post_install runs under a throwaway HOME), so the
    # bundle is mirrored on each invocation instead, which is what install.sh
    # does once at install time. opt_* paths stay valid across upgrades, and
    # the daemon records the exec'd path in its launchd plist.
    (bin/"akasha").write <<~SH
      #!/bin/sh
      # Homebrew launcher for akasha: mirror the keg's provider bundle into the
      # directory the daemon reads, then exec the real binary.
      src="#{opt_pkgshare}/templates"
      if [ -z "${AKASHA_SHIPPED_TEMPLATES_DIR:-}" ] && [ -n "${HOME:-}" ] && [ -d "$src" ]; then
        dist="$HOME/.akasha/templates.dist"
        if { [ -d "$HOME/.akasha" ] || mkdir -m 0700 "$HOME/.akasha"; } 2>/dev/null \\
           && mkdir -p "$dist" 2>/dev/null; then
          for f in "$src"/*.yaml "$src"/*.yaml.sig; do
            [ -f "$f" ] || continue
            t="$dist/${f##*/}"
            if ! cmp -s "$f" "$t" 2>/dev/null; then
              cp "$f" "$t" 2>/dev/null \\
                || { echo "akasha (homebrew): could not refresh $t; the daemon may report 'No templates loaded.'" >&2; break; }
            fi
          done
        fi
      fi
      exec "#{opt_libexec}/akasha" "$@"
    SH
    chmod 0555, bin/"akasha"
  end

  def caveats
    <<~EOS
      Finish the install:

        akasha setup

      It scans for credentials, vaults them on confirmation, registers the
      daemon as a login service, and writes the MCP config for Claude Code.

      On Linux, unlock a Secret Service keyring (gnome-keyring over D-Bus)
      before setup, and install bubblewrap for `akasha run`:
        https://github.com/inferlabshq/akasha/blob/main/docs/getting-started.md#linux-prerequisites

      After `brew upgrade akasha`:  akasha stop && akasha start
      On Linux the systemd unit records the versioned Cellar path, so after an
      upgrade there run `akasha setup` again to re-register the service.

      Alpha: do not use it to protect secrets you cannot rotate.
    EOS
  end

  test do
    # brew test runs with HOME set to testpath, so this also proves the
    # launcher mirrors the bundle where the daemon reads it.
    out = shell_output("#{bin}/akasha version")
    assert_match "akasha v0.1.0-alpha.7", out
    assert_match "official trust root: present", out
    assert_path_exists testpath/".akasha/templates.dist/aws.yaml"
    assert_path_exists testpath/".akasha/templates.dist/aws.yaml.sig"
  end
end
