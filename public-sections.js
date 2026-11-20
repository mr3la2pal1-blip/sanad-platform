/* Public updates and partner directory for Sanad. Public rows are filtered by database RLS. */
(function () {
  const api = 'https://vovpbesmqgvfpjxslzbx.supabase.co/rest/v1/';
  const key = 'sb_publishable_1T4fLsk02CYnxnJOFVGhtw_Mh-t9V3j';
  const headers = { apikey: key, Authorization: 'Bearer ' + key };
  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const safeUrl = value => {
    try { const url = new URL(String(value || '')); return ['https:', 'http:'].includes(url.protocol) ? url.href : ''; }
    catch { return ''; }
  };

  async function loadAnnouncements() {
    const host = document.getElementById('publicAnnouncementsList');
    if (!host) return;
    try {
      const response = await fetch(api + 'announcements?select=id,title,body,image_url,published_at,created_at&is_published=eq.true&order=published_at.desc.nullslast,created_at.desc&limit=12', { headers });
      const rows = await response.json();
      if (!response.ok) throw new Error('HTTP ' + response.status);
      host.innerHTML = rows.length ? rows.map(row => {
        const date = row.published_at || row.created_at;
        const image = safeUrl(row.image_url);
        return '<article>' + (image ? '<img src="' + esc(image) + '" alt="صورة لقصة أثر من سند" loading="lazy" style="width:100%;max-height:220px;object-fit:cover;border-radius:12px;margin-bottom:10px">' : '') + '<small>قصة أثر / تحديث من سند</small><h3>' + esc(row.title) + '</h3><p>' + esc(row.body) + '</p><p class="subtle">' + (date ? new Date(date).toLocaleDateString('ar') : '') + '</p></article>';
      }).join('') : '<article><p class="empty">لا توجد تحديثات منشورة حاليًا.</p></article>';
    } catch (error) {
      console.error('Public announcements failed:', error);
      host.innerHTML = '<article><p class="empty">تعذر تحميل التحديثات حاليًا.</p></article>';
    }
  }

  async function loadPartners() {
    const host = document.getElementById('publicPartnersList');
    if (!host) return;
    const categories = { community: 'مبادرة مجتمعية', institutional: 'مؤسسة', business: 'شركة', media: 'جهة إعلامية', other: 'شريك' };
    try {
      const response = await fetch(api + 'partners?select=name,category,description,website_url,logo_url&is_published=eq.true&order=display_order.asc,created_at.desc', { headers });
      const rows = await response.json();
      if (!response.ok) throw new Error('HTTP ' + response.status);
      host.innerHTML = rows.length ? rows.map(partner => {
        const logo = safeUrl(partner.logo_url), website = safeUrl(partner.website_url);
        return '<article>' + (logo ? '<img src="' + esc(logo) + '" alt="شعار ' + esc(partner.name) + '" loading="lazy" style="width:100%;max-width:180px;max-height:90px;object-fit:contain;margin-bottom:12px">' : '') +
          '<small>' + esc(categories[partner.category] || categories.other) + '</small><h3>' + esc(partner.name) + '</h3><p>' + esc(partner.description) + '</p>' +
          (website ? '<a class="btn" href="' + esc(website) + '" target="_blank" rel="noopener noreferrer">زيارة موقع الشريك</a>' : '') + '</article>';
      }).join('') : '<article><p class="empty">لا توجد شراكات منشورة حاليًا.</p></article>';
    } catch (error) {
      console.error('Public partners failed:', error);
      host.innerHTML = '<article><p class="empty">تعذر تحميل قائمة الشركاء حاليًا.</p></article>';
    }
  }

  document.addEventListener('DOMContentLoaded', () => { loadAnnouncements(); loadPartners(); });
})();
