_: super: {
  unzip = super.unzip.overrideAttrs (old: {
    patches = [
      ./0000-CVE-2014-8139.patch
      ./0001-CVE-2014-8140.patch
      ./0002-CVE-2014-8141.patch
      ./0003-CVE-2014-9636.patch
      ./0004-CVE-2015-7696.patch
      ./0005-CVE-2015-7697.patch
      ./0006-CVE-2014-9913.patch
      ./0007-CVE-2016-9844.patch
      ./0008-CVE-2018-18384.patch
      ./0009-do-not-hardcode-cc.patch
      /*
      0010
      */
      (super.fetchurl {
        url = "https://github.com/madler/unzip/commit/41beb477c5744bc396fa1162ee0c14218ec12213.patch";
        name = "CVE-2019-13232-1.patch";
        sha256 = "04jzd6chg9fw4l5zadkfsrfm5llrd7vhd1dgdjjd29nrvkrjyn14";
      })
      /*
      0011
      */
      (super.fetchurl {
        url = "https://github.com/madler/unzip/commit/47b3ceae397d21bf822bc2ac73052a4b1daf8e1c.patch";
        name = "CVE-2019-13232-2.patch";
        sha256 = "0iy2wcjyvzwrjk02iszwcpg85fkjxs1bvb9isvdiywszav4yjs32";
      })
      /*
      0012
      */
      (super.fetchurl {
        url = "https://github.com/madler/unzip/commit/6d351831be705cc26d897db44f878a978f4138fc.patch";
        name = "CVE-2019-13232-3.patch";
        sha256 = "1jvs7dkdqs97qnsqc6hk088alhv8j4c638k65dbib9chh40jd7pf";
      })
      ./0013-initialize-the-symlink-flag.patch
      ./0014-cve-2022-0529-and-cve-2022-0530.patch
      ./0015-implicit-declarations-fix.patch
      ./0016-CVE-2021-4217.patch
    ];
  });
}
