document.getElementById("year").textContent=new Date().getFullYear();document.getElementById("interest").addEventListener("click",async()=>{const msg="مرحبًا، أرغب بالتواصل مع فريق منصة سند لمعرفة فرص التطوع أو التعاون المؤسسي.";const status=document.getElementById("status");try{await navigator.clipboard.writeText(msg);status.textContent="تم نسخ رسالة الاهتمام. يمكنك لصقها وإرسالها بالطريقة التي تناسبك."}catch{status.textContent=msg}});if("serviceWorker"in navigator&&location.protocol.startsWith("http"))addEventListener("load",()=>navigator.serviceWorker.register("./sw.js").catch(()=>{}));
// Accessibility and public demo interactions
(()=>{let scale=1;document.getElementById('fontUp')?.addEventListener('click',()=>{scale=Math.min(1.3,scale+.1);document.documentElement.style.fontSize=(16*scale)+'px'});document.getElementById('fontDown')?.addEventListener('click',()=>{scale=Math.max(.85,scale-.1);document.documentElement.style.fontSize=(16*scale)+'px'});document.getElementById('contrast')?.addEventListener('click',()=>document.body.classList.toggle('high-contrast'));document.getElementById('theme')?.addEventListener('click',()=>document.body.classList.toggle('dark'));document.getElementById('lang')?.addEventListener('click',()=>{alert('النسخة الإنجليزية قيد الإعداد. English version is planned.');});const search=document.getElementById('siteSearch');search?.addEventListener('input',()=>{const q=search.value.trim().toLowerCase();let n=0;document.querySelectorAll('main section').forEach(s=>{const hit=!q||s.innerText.toLowerCase().includes(q);s.hidden=!hit;if(hit)n++});document.getElementById('searchCount').textContent=q?'الأقسام المطابقة: '+n:''});['publicAid','volunteerInterest'].forEach(id=>document.getElementById(id)?.addEventListener('submit',e=>{e.preventDefault();const target=id==='publicAid'?'aidNotice':'volunteerNotice';document.getElementById(target).textContent='هذه نسخة تجريبية: لم يتم إرسال أو تخزين البيانات. سيتم تفعيل الإرسال بعد تجهيز الخادم الآمن.';}));})();


// Responsive navigation menu for tablet and mobile
(()=> {
 const header=document.querySelector('body > header');
 if(!header || header.querySelector('.mobile-menu-toggle')) return;
 const toggle=document.createElement('button');
 toggle.type='button';
 toggle.className='mobile-menu-toggle';
 toggle.setAttribute('aria-expanded','false');
 toggle.setAttribute('aria-controls','primary-navigation');
 toggle.innerHTML='<span aria-hidden="true">☰</span><span>القائمة</span>';
 const nav=header.querySelector('nav');
 if(nav){nav.id='primary-navigation';header.querySelector('.brand')?.after(toggle);}
 const close=()=>{header.classList.remove('is-menu-open');toggle.setAttribute('aria-expanded','false');toggle.innerHTML='<span aria-hidden="true">☰</span><span>القائمة</span>';};
 toggle.addEventListener('click',()=>{
  const opening=!header.classList.contains('is-menu-open');
  header.classList.toggle('is-menu-open',opening);
  toggle.setAttribute('aria-expanded',String(opening));
  toggle.innerHTML=opening?'<span aria-hidden="true">✕</span><span>إغلاق</span>':'<span aria-hidden="true">☰</span><span>القائمة</span>';
 });
 header.querySelectorAll('nav a, .outline').forEach(link=>link.addEventListener('click',close));
 document.addEventListener('keydown',event=>{if(event.key==='Escape')close();});
 window.addEventListener('resize',()=>{if(window.innerWidth>820)close();});
})();
