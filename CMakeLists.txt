cmake_minimum_required(VERSION 3.19)
project(YiJuanShanHe VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick Qml QuickControls2 Sql Svg Network)
qt_standard_project_setup()
qt_policy(SET QTP0001 NEW)
set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_executable(YiJuanShanHe WIN32
    main.cpp
    src/homecontroller.cpp
    src/homecontroller.h
    src/poemcatalog.cpp
    src/poemcatalog.h
    src/poetlifemodel.cpp
    src/poetlifemodel.h
    src/journeymodel.cpp
    src/journeymodel.h
    src/shicicalendar.cpp
    src/shicicalendar.h
    src/interactionengine.cpp
    src/interactionengine.h
    src/personalspace.cpp
    src/personalspace.h
    src/imageryexplorer.cpp
    src/imageryexplorer.h
    src/aiassistant.cpp
    src/aiassistant.h
)

qt_add_qml_module(YiJuanShanHe
    URI YiJuanShanHe
    VERSION 1.0
    NO_GENERATE_QMLTYPES
    QML_FILES
        qml/Theme.qml
        qml/Main.qml
        qml/components/MountainScene.qml
        qml/components/ArtBackground.qml
        qml/components/SkyChart.qml
        qml/components/JourneyMap.qml
        qml/components/FeatureCard.qml
        qml/components/ArchiveFilter.qml
        qml/components/ThemeComboBox.qml
        qml/components/LifeStageCard.qml
        qml/components/LifePortrait.qml
        qml/components/LifeChronicleNode.qml
        qml/components/InkVignette.qml
        qml/components/InteractionLobby.qml
        qml/components/InteractionStage.qml
        qml/components/FeihuaStage.qml
        qml/components/ChainStage.qml
        qml/components/PuzzleStage.qml
        qml/components/InteractionResult.qml
        qml/components/PersonalOverview.qml
        qml/PoetryArchive.qml
        qml/PoetBiography.qml
        qml/PoetJourney.qml
        qml/PoetryCalendarView.qml
        qml/PoetryInteraction.qml
        qml/PersonalSpace.qml
        qml/ImageryExplore.qml
        qml/AiAssistantPage.qml
)

set(optional_ai_background)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/picture/3aa8384f7b70a0cfa526f5c54527ff05.jpg")
    list(APPEND optional_ai_background picture/3aa8384f7b70a0cfa526f5c54527ff05.jpg)
endif()

qt_add_resources(YiJuanShanHe "poet_lives_data"
    PREFIX "/"
    FILES data/poets.json data/journeys.json data/journey-readings.json data/imagery.json data/china-outline.svg data/china-outline-overlay.svg shici.txt shili.png
        ${optional_ai_background}
        picture/b420b20827e9cefed34f0277a69dd4dd.jpg
        picture/ec99fa2a133e9c6dd4e0ad5755896c68.jpg
        picture/xingyun1.jpg picture/xingyun2.jpg
        picture/xinglv1.png picture/xinglv2.png
        picture/yaji1.png picture/feihua1.png picture/jielong1.png picture/canjuan1.png
        picture/feihua_bg1.jpg picture/feihua_bg2.jpg
        picture/ai_bg1.jpg picture/ai_bg2.jpg
        picture/jielong_bg1.jpg picture/jielong_bg2.jpg
        picture/canjuan_bg1.jpg picture/canjuan_bg2.jpg
)
configure_file(data/poets.json "${CMAKE_CURRENT_BINARY_DIR}/data/poets.json" COPYONLY)
configure_file(data/journeys.json "${CMAKE_CURRENT_BINARY_DIR}/data/journeys.json" COPYONLY)
configure_file(data/imagery.json "${CMAKE_CURRENT_BINARY_DIR}/data/imagery.json" COPYONLY)
configure_file(shici.txt "${CMAKE_CURRENT_BINARY_DIR}/shici.txt" COPYONLY)

set(YIJUANSHANHE_AI_SERVICE_URL "http://127.0.0.1:8765" CACHE STRING "AI backend service URL (no API credentials)")
target_compile_definitions(YiJuanShanHe PRIVATE YIJUANSHANHE_AI_SERVICE_URL=\"${YIJUANSHANHE_AI_SERVICE_URL}\")
target_link_libraries(YiJuanShanHe PRIVATE Qt6::Quick Qt6::Qml Qt6::QuickControls2 Qt6::Sql Qt6::Svg Qt6::Network)

include(CTest)
if(BUILD_TESTING)
    qt_add_executable(catalog_tests
        tests/catalog_test.cpp
        src/homecontroller.cpp
        src/homecontroller.h
        src/poemcatalog.cpp
        src/poemcatalog.h
        src/shicicalendar.cpp
        src/shicicalendar.h
    )
    target_link_libraries(catalog_tests PRIVATE Qt6::Core Qt6::Sql)
    add_test(NAME catalog_data COMMAND catalog_tests)

    qt_add_executable(poet_lives_tests
        tests/poet_lives_test.cpp
        src/poetlifemodel.cpp
        src/poetlifemodel.h
    )
    qt_add_resources(poet_lives_tests "poet_lives_test_data"
        PREFIX "/"
        FILES data/poets.json
    )
    target_link_libraries(poet_lives_tests PRIVATE Qt6::Core)
    add_test(NAME poet_lives_data COMMAND poet_lives_tests)

    qt_add_executable(journey_tests
        tests/journey_test.cpp
        src/journeymodel.cpp
        src/journeymodel.h
    )
    qt_add_resources(journey_tests "journey_test_data"
        PREFIX "/"
        FILES data/poets.json data/journeys.json data/journey-readings.json
    )
    target_link_libraries(journey_tests PRIVATE Qt6::Core Qt6::Sql)
    add_test(NAME journey_data COMMAND journey_tests)

    qt_add_executable(shici_calendar_tests
        tests/shici_calendar_test.cpp
        src/shicicalendar.cpp
        src/shicicalendar.h
    )
    qt_add_resources(shici_calendar_tests "shici_test_data"
        PREFIX "/"
        FILES shici.txt
    )
    target_link_libraries(shici_calendar_tests PRIVATE Qt6::Core)
    add_test(NAME shici_calendar_data COMMAND shici_calendar_tests)

    qt_add_executable(shici_archive_tests
        tests/shici_archive_test.cpp
        src/poemcatalog.cpp
        src/poemcatalog.h
        src/shicicalendar.cpp
        src/shicicalendar.h
    )
    qt_add_resources(shici_archive_tests "shici_archive_test_data"
        PREFIX "/"
        FILES shici.txt
    )
    target_link_libraries(shici_archive_tests PRIVATE Qt6::Core Qt6::Sql)
    add_test(NAME shici_archive_data COMMAND shici_archive_tests)

    qt_add_executable(interaction_tests
        tests/interaction_test.cpp
        src/interactionengine.cpp
        src/interactionengine.h
        src/poemcatalog.cpp
        src/poemcatalog.h
        src/shicicalendar.cpp
        src/shicicalendar.h
    )
    qt_add_resources(interaction_tests "interaction_test_data" PREFIX "/" FILES shici.txt)
    target_link_libraries(interaction_tests PRIVATE Qt6::Core Qt6::Sql)
    add_test(NAME interaction_data COMMAND interaction_tests)

    qt_add_executable(personal_space_tests
        tests/personal_space_test.cpp
        src/personalspace.cpp
        src/personalspace.h
        src/interactionengine.cpp
        src/interactionengine.h
        src/poemcatalog.cpp
        src/poemcatalog.h
        src/shicicalendar.cpp
        src/shicicalendar.h
    )
    qt_add_resources(personal_space_tests "personal_test_data" PREFIX "/" FILES shici.txt)
    target_link_libraries(personal_space_tests PRIVATE Qt6::Core Qt6::Sql)
    add_test(NAME personal_space_data COMMAND personal_space_tests)

    qt_add_executable(imagery_tests
        tests/imagery_test.cpp
        src/imageryexplorer.cpp src/imageryexplorer.h
        src/poemcatalog.cpp src/poemcatalog.h
        src/shicicalendar.cpp src/shicicalendar.h
    )
    qt_add_resources(imagery_tests "imagery_test_data" PREFIX "/" FILES shici.txt data/imagery.json)
    target_link_libraries(imagery_tests PRIVATE Qt6::Core Qt6::Sql)
    add_test(NAME imagery_data COMMAND imagery_tests)

    qt_add_executable(ai_assistant_tests
        tests/ai_assistant_test.cpp
        src/aiassistant.cpp
        src/aiassistant.h
    )
    target_link_libraries(ai_assistant_tests PRIVATE Qt6::Core Qt6::Gui Qt6::Sql Qt6::Network)
    add_test(NAME ai_assistant_data COMMAND ai_assistant_tests)
endif()

install(TARGETS YiJuanShanHe
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

qt_generate_deploy_app_script(
    TARGET YiJuanShanHe
    OUTPUT_SCRIPT deploy_script
    NO_UNSUPPORTED_PLATFORM_ERROR
)
install(SCRIPT ${deploy_script})
