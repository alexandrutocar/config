final: super: {
  report = {
    disk = let
      _find = let
        /*
        * Finds a disk in a facter report by its unix device name.
        *
        * Example:
        *   lib.report.disk.find.by-unix-name "/dev/sda" report -> { unix_device_names = [...]; resources = [...]; ... }
        *
        * Implementation details:
        * - Searches report.hardware.disk for a disk whose unix_device_names list contains the given name.
        * - Delegates to lists.findSingle to enforce exactly one match.
        *
        * Edge cases:
        * - Throws if no disk matches.
        * - Throws if more than one disk matches.
        */
        _by-unix-name = unix_device_name: report:
          super.lists.findSingle
          (disk: builtins.elem unix_device_name disk.unix_device_names)
          (throw "Could not find disk with specified unix device name.")
          (throw "Found multiple disks with the same specified unix device name.")
          report.hardware.disk;
      in {
        /*
        * Finds a disk in a facter report by its /dev/disk/by-id identifier.
        *
        * Example:
        *   lib.report.disk.find.by-id "ata-SAMSUNG_..." report -> { unix_device_names = [...]; resources = [...]; ... }
        *
        * Implementation details:
        * - Prepends "/dev/disk/by-id/" to the given id and delegates to by-unix-name.
        *
        * Edge cases:
        * - Throws if no disk matches.
        * - Throws if more than one disk matches.
        */
        by-id = id: report: _by-unix-name "/dev/disk/by-id/${id}" report;

        by-unix-name = _by-unix-name;
      };

      /*
      * Finds a resource of a given type within a disk's resource list.
      *
      * Example:
      *   lib.report.disk.resources.find.by-type "size" disk -> { type = "size"; value_1 = 512; value_2 = 1073741824; }
      *
      * Implementation details:
      * - Filters disk.resources for entries whose type field matches the given type.
      * - Delegates to lists.findSingle to enforce exactly one match.
      *
      * Edge cases:
      * - Throws if no resource of the given type is found.
      * - Throws if more than one resource of the given type is found.
      */
      _resources.find.by-type = type: disk:
        super.lists.findSingle
        (resource: resource.type == type)
        (throw "Did not find resource of type '${type}'.")
        (throw "Found multiple resources of type '${type}'.")
        disk.resources;
    in {
      /*
      * Returns the total size of a disk (in bytes) from a facter report, identified by its by-id name.
      *
      * Example:
      *   lib.report.disk.extra.size "ata-SAMSUNG_..." report -> 512110190592
      *
      * Implementation details:
      * - Locates the disk via find.by-id, then retrieves its "size" resource.
      * - Multiplies value_1 and value_2 from the size resource to produce the byte count.
      *
      * Edge cases:
      * - Throws if the disk or its size resource cannot be uniquely found.
      */
      extra.size = id: report: let
        size = _resources.find.by-type "size" (_find.by-id id report);
      in
        size.value_1 * size.value_2;

      find = _find;

      resources = _resources;
    };

    memory = {
      /*
      * Returns the total physical memory size (in bytes) across all memory modules in a facter report.
      *
      * Example:
      *   lib.report.memory.extra.size report -> 34359738368
      *
      * Implementation details:
      * - Iterates over report.hardware.memory (one entry per memory module).
      * - For each module, sums the range values of all resources with type "phys_mem".
      * - Accumulates across all modules with foldl'.
      *
      * Edge cases:
      * - Returns 0 if there are no memory modules or no "phys_mem" resources.
      * - Does not validate that ranges are non-overlapping.
      */
      extra.size = report:
        builtins.foldl'
        (total: memory:
          total
          + builtins.foldl'
          (range: resource: range + resource.range)
          0
          (builtins.filter (resource: resource.type == "phys_mem") memory.resources))
        0
        report.hardware.memory;
    };
  };
}
