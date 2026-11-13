/*
IOS Theos Template Komaru
Jailed (NoJB) Mod Menu Template for iOS Games
By aq9
https://github.com/VenerableCode/iOS-Theos-ModMenuTemp-NoJB
#include "BasicHacks.h"
#include "../MenuLoad/Includes.h"

bool running = true;

namespace offsets {
    constexpr uintptr_t OFFSET_GWorld                   = 0x04d5b510;
    constexpr uintptr_t OFFSET_OwningGameInstance       = 0x320;
    constexpr uintptr_t OFFSET_LocalPlayers             = 0x38;
    constexpr uintptr_t OFFSET_LocalPlayerController    = 0x30;
    constexpr uintptr_t OFFSET_PlayerCameraManager      = 0x480;
}

void* BasicHacks::HacksThread(void* arg)
{

    while(running)
    {   
        using namespace offsets;

        usleep(100);
        //ARK FOV Changer example
        uintptr_t BaseAddr                =  (uintptr_t)_dyld_get_image_header(0);
        uintptr_t GWorld                  = KomaruPatch::ReadMem(BaseAddr + OFFSET_GWorld);
        uintptr_t OwningGameInstance      = KomaruPatch::ReadMem(GWorld + OFFSET_OwningGameInstance);
        uintptr_t LocalPlayers            = KomaruPatch::ReadMem(OwningGameInstance + OFFSET_LocalPlayers);
        uintptr_t LocalPlayer             = KomaruPatch::ReadMem(LocalPlayers);
        uintptr_t LocalPlayerController   = KomaruPatch::ReadMem(LocalPlayer + OFFSET_LocalPlayerController);
        uintptr_t PlayerCameraManager     = KomaruPatch::ReadMem(LocalPlayerController + OFFSET_PlayerCameraManager);

//      KomaruPatch::WriteMem<DType>(Ptr   + Offset, Value);
        KomaruPatch::WriteMem<float>(PlayerCameraManager + 0x33c0, KTempVars.CameraFOV); // MenuLoad -> Includes.h

    } return NULL; }


 void BasicHacks::Initialize()
{
    pthread_t BasicHacksThread;
    pthread_create(&BasicHacksThread, nullptr, HacksThread, nullptr);
}

*/

// BasicHacks.mm 
// by silentNinjaBee - using GCD for timing and thread management
#import "BasicHacks.h"
#include "../MenuLoad/Includes.h"
#include <vector>
#include <dlfcn.h>

struct Vector3 { float x, y, z; };
std::vector<Vector3> enemyPositions; 

// Типы функций Il2Cpp
typedef void* (*il2cpp_domain_get_t)();
typedef void* (*il2cpp_domain_assembly_open_t)(void*, const char*);
typedef void* (*il2cpp_assembly_get_image_t)(void*);
typedef void* (*il2cpp_class_from_name_t)(void*, const char*, const char*);
typedef void* (*il2cpp_class_get_field_from_name_t)(void*, const char*);
typedef void (*il2cpp_field_static_get_value_t)(void*, void*);

void BasicHacks::HacksThread() {
    void* handle = dlopen("UnityFramework", RTLD_NOW);
    if (!handle) return;

    auto domain_get = (il2cpp_domain_get_t)dlsym(handle, "il2cpp_domain_get");
    auto assembly_open = (il2cpp_domain_assembly_open_t)dlsym(handle, "il2cpp_domain_assembly_open");
    auto assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(handle, "il2cpp_assembly_get_image");
    auto class_from_name = (il2cpp_class_from_name_t)dlsym(handle, "il2cpp_class_from_name");
    auto class_get_field = (il2cpp_class_get_field_from_name_t)dlsym(handle, "il2cpp_class_get_field_from_name");
    auto field_static_get = (il2cpp_field_static_get_value_t)dlsym(handle, "il2cpp_field_static_get_value");

    if (!domain_get) return;

    void* domain = domain_get();
    void* assembly = assembly_open(domain, "Assembly-CSharp.dll");
    void* image = assembly_get_image(assembly);
    
    // Ищем класс Player
    void* playerClass = class_from_name(image, "", "Player"); 
    if (!playerClass) return;

    // Ищем статический список Instances
    void* instancesField = class_get_field(playerClass, "Instances");
    if (!instancesField) return;

    uintptr_t instancesList = 0;
    field_static_get(instancesField, &instancesList);
    if (!instancesList) return;

    // В C# List<T> элементы лежат в массиве по 0x10, а размер по 0x18
    uintptr_t itemsArray = KomaruPatch::ReadMem(instancesList + 0x10);
    int size = KomaruPatch::ReadMem<int>(instancesList + 0x18);
    if (size <= 0 || size > 100) return;

    enemyPositions.clear();

    for (int i = 0; i < size; i++) {
        // Получаем объект игрока (указатель 8 байт)
        uintptr_t entity = KomaruPatch::ReadMem(itemsArray + (i * 0x8));
        if (!entity) continue;
        
        // Читаем твои координаты по оффсету 0x268 !!!
        Vector3 pos = KomaruPatch::ReadMem<Vector3>(entity + 0x268);
        
        // Проверка, чтобы отсеять нулевые координаты
        if (pos.x != 0.0f && pos.y != 0.0f && pos.z != 0.0f) {
            enemyPositions.push_back(pos);
        }
    }
}

// Таймер
@implementation GameLoop { dispatch_source_t _timer; }
- (void)start {
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(0, 0));
    dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, 0), 10000000, 0); // 10ms
    dispatch_source_set_event_handler(_timer, ^{ BasicHacks::HacksThread(); });
    dispatch_resume(_timer);
}
@end

void BasicHacks::Initialize(){
    static GameLoop *gameLoop = [[GameLoop alloc] init];
    [gameLoop start];
}
