import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tvbox_flutter/providers/source_provider.dart';
import 'package:tvbox_flutter/ui/widgets/video_card.dart';
import 'package:tvbox_flutter/ui/search/search_page.dart';
import 'package:tvbox_flutter/ui/settings/settings_page.dart';
import 'package:tvbox_flutter/ui/history/history_page.dart';
import 'package:tvbox_flutter/ui/favorite/favorite_page.dart';
import 'package:tvbox_flutter/ui/cloud_drive/cloud_drive_page.dart';
import 'package:tvbox_flutter/ui/live/live_page.dart';
import 'package:tvbox_flutter/ui/widgets/bottom_nav_bar.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _tabController;
  bool _isLoading = true;

  final List<Widget> _pages = const [
    HomeContent(),
    LivePage(),
    CloudDrivePage(),
    HistoryPage(),
    FavoritePage(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
    _loadHomeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    setState(() => _isLoading = true);
    
    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
    await sourceProvider.loadHomeContent();
    
    if (sourceProvider.categories.isNotEmpty) {
      _tabController = TabController(
        length: sourceProvider.categories.length,
        vsync: this,
      );
    }
    
    setState(() => _isLoading = false);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
    _loadHomeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    setState(() => _isLoading = true);
    
    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
    await sourceProvider.loadHomeContent();
    
    if (sourceProvider.categories.isNotEmpty) {
      _tabController = TabController(
        length: sourceProvider.categories.length,
        vsync: this,
      );
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TVBox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
        bottom: _isLoading || Provider.of<SourceProvider>(context).categories.isEmpty
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: Provider.of<SourceProvider>(context)
                    .categories
                    .map((category) => Tab(text: category['name']))
                    .toList(),
              ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: SpinKitFadingCircle(
          color: Colors.blue,
          size: 50.0,
        ),
      );
    }

    final sourceProvider = Provider.of<SourceProvider>(context);
    
    if (sourceProvider.categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('请先添加数据源'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
              child: const Text('添加数据源'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: sourceProvider.categories.map((category) {
        return _buildCategoryContent(category);
      }).toList(),
    );
  }

  Widget _buildCategoryContent(Map<String, dynamic> category) {
    final videos = category['videos'] ?? [];
    
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return VideoCard(
          video: video,
          onTap: () {
            // 跳转到详情页
          },
        );
      },
    );
  }
}