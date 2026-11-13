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

class KomaruPatch {
public:
    template <typename T>
    static T ReadMem(uintptr_t address) {
        if (address == 0) return T();
        T value = {};
        vm_size_t size = sizeof(T);
        kern_return_t kr = vm_read_overwrite(mach_task_self(), (vm_address_t)address, (vm_size_t)sizeof(T), (vm_address_t)&value, &size);
        if (kr != KERN_SUCCESS) return T();
        return value;
    }

    template <typename T>
    static bool WriteMem(uintptr_t address, const T& value) {
        if (address == 0) return false;
        vm_protect(mach_task_self(), (vm_address_t)address, sizeof(T), false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
        memcpy(reinterpret_cast<void*>(address), &value, sizeof(T));
        return true; 
    }
};
