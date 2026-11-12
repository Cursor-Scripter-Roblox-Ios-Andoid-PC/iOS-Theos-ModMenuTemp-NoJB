/*
IOS Theos Template Komaru
Jailed (NoJB) Mod Menu Template for iOS Games
By aq9
https://github.com/VenerableCode/iOS-Theos-ModMenuTemp-NoJB
#pragma once

#include <iostream>

class KomaruPatch {
public:
    static bool IsValidPointer(uintptr_t address) {
        return address > 0x100000000 && address < 0x3000000000;
    }

    static uintptr_t ReadMem(uintptr_t address) {
        if (!IsValidPointer(address)) {
            return 0;
        }
        return *reinterpret_cast<uintptr_t*>(address);
    }

    template <typename T>
    static void WriteMem(uintptr_t address, const T& value) {
        if (!IsValidPointer(address)) {
            return;
        }
        *reinterpret_cast<T*>(address) = value;
    }
};
*/

    // Attempt to make the memory handling more robust, with minimal use of mach api's to reduce any extra entitlements

#pragma once

#include <mach/mach.h>
#include <cstring>
#include <sys/sysctl.h>

class KomaruPatch {
public:
    static bool IsValidPointer(uintptr_t address) {
        if (address == 0) return false;

        mach_port_t task = mach_task_self();
        vm_address_t region_address = (vm_address_t)address;
        vm_size_t region_size = 0;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t object_name;

        kern_return_t kr = vm_region_64(task, &region_address, &region_size, VM_REGION_BASIC_INFO_64,
                                         (vm_region_info_t)&info, &info_count, &object_name);

        if (kr != KERN_SUCCESS) {
            return false;
        }

        return address >= region_address && address < (region_address + region_size);
    }

    template <typename T>
    static T ReadMem(uintptr_t address) {
        if (!IsValidPointer(address)) {
            return T();
        }

        mach_port_t task = mach_task_self();
        T value = {};
        vm_size_t size = sizeof(T);
        kern_return_t kr = vm_read_overwrite(task, (vm_address_t)address, (vm_size_t)sizeof(T), (vm_address_t)&value, &size);

        if (kr != KERN_SUCCESS || size != sizeof(T)) {
            return T();
        }

        return value;
    }

    template <typename T>
    static bool WriteMem(uintptr_t address, const T& value) {
        if (!IsValidPointer(address)) {
            return false;
        }

        mach_port_t task = mach_task_self();

        vm_address_t vm_address = (vm_address_t)address;
        vm_size_t vm_size = 0;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t object_name;

        kern_return_t kr = vm_region_64(task, &vm_address, &vm_size, VM_REGION_BASIC_INFO_64,
                                         (vm_region_info_t)&info, &info_count, &object_name);

        if (kr != KERN_SUCCESS || !(info.protection & VM_PROT_WRITE)) {
            kr = vm_protect(task, (vm_address_t)address, sizeof(T), false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
            if (kr != KERN_SUCCESS) {
                return false;
            }
        }

        memcpy(reinterpret_cast<void*>(address), &value, sizeof(T));

        if (!(info.protection & VM_PROT_WRITE)) {
            vm_protect(task, (vm_address_t)address, sizeof(T), false, info.protection);
        }

        return true;
    }
};
 
